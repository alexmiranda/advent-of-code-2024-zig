const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const window = std.mem.window;
const trimRight = std.mem.trimRight;
const swap = std.mem.swap;
const example = @embedFile("example.txt");

const Segment = union(enum) {
    free: packed struct { pos: u64, len: u8 },
    file: packed struct { pos: u64, len: u8, id: u64 },
};

const Disk = struct {
    ally: std.mem.Allocator,
    segments: *std.ArrayList(Segment),

    fn initParse(ally: std.mem.Allocator, buffer: []const u8) !Disk {
        var segments = try std.ArrayList(Segment).initCapacity(ally, 0);
        errdefer segments.deinit();

        // allocate enough memory to hold all segments
        try segments.ensureTotalCapacity(buffer.len);

        // read each pair and add file and free space segments
        var pos: u64 = 0;
        var file_id: u64 = 0;
        var it = window(u8, trimRight(u8, buffer, "\n"), 2, 2);
        while (it.next()) |chunk| : (file_id += 1) {
            const file_len = chunk[0] - '0';
            const file: Segment = .{ .file = .{ .pos = pos, .id = file_id, .len = file_len } };
            pos +|= @intCast(file_len);
            segments.appendAssumeCapacity(file);

            if (chunk.len == 1) break;
            const free_len = chunk[1] - '0';
            if (free_len == 0) continue;
            const free: Segment = .{ .free = .{ .pos = pos, .len = free_len } };
            pos +|= @intCast(free_len);
            segments.appendAssumeCapacity(free);
        }

        return .{ .ally = ally, .segments = &segments };
    }

    fn deinit(self: *Disk) void {
        self.segments.deinit();
    }

    fn compact(self: *Disk) !u64 {
        var segments = self.segments.items;
        var left: usize = 1;
        var right: usize = self.segments.items.len - 1;
        outer: while (left < right) {
            // find the first available free space
            var free = inner: while (left < right) : (left += 1) {
                switch (segments[left]) {
                    .free => |*data| break data,
                    .file => continue :inner,
                }
            } else break :outer;

            // find the right-most file
            var file = inner: while (right > left) : (right -= 1) {
                switch (segments[right]) {
                    .file => |*data| break data,
                    .free => continue :inner,
                }
            } else break :outer;

            if (free.len >= file.len) {
                // adjust length
                const delta = free.len - file.len;
                free.len = file.len;

                // swap positions
                swap(Segment, &segments[left], &segments[right]);
                free.pos, file.pos = .{ file.pos, free.pos };

                // add remaining free space
                if (delta > 0) {
                    try self.segments.insert(left + 1, .{ .free = .{ .pos = file.pos + file.len, .len = delta } });
                }
            } else {
                segments[left] = .{ .file = .{ .pos = free.pos, .len = free.len, .id = file.id } };
                file.len = file.len - free.len;
            }

            // move left and right pointers before continuing
            left += 1;
        }

        // print("{any}\n", .{self});
        return checksum(segments);
    }

    fn compactNoFragmentation(self: *Disk) !u64 {
        var seen = std.AutoHashMapUnmanaged(u64, void){};
        defer seen.deinit(self.ally);

        var segments = self.segments.items;
        var slide = self.segments.items.len - 1;
        outer: while (slide > 0) : (slide -= 1) {
            var file = switch (segments[slide]) {
                .file => |*data| data,
                .free => continue :outer,
            };

            // ensure that we don't try to move the same file twice... even though it wouldn't be possible
            // if (try seen.fetchPut(self.ally, file.id, {})) |_| {
            //     continue :outer;
            // }

            for (segments[1..slide], 1..) |*segment, i| {
                var free = switch (segment.*) {
                    .free => |*data| data,
                    .file => continue,
                };

                if (free.len >= file.len) {
                    const delta = free.len - file.len;
                    free.len = file.len;

                    // swap positions
                    swap(Segment, &segments[i], &segments[slide]);
                    free.pos, file.pos = .{ file.pos, free.pos };

                    // add remaining free space
                    if (delta > 0) {
                        try self.segments.insert(i + 1, .{ .free = .{ .pos = file.pos + file.len, .len = delta } });
                        slide += 1;
                    }
                    continue :outer;
                }
            }
        }

        // print("{any}\n", .{self});
        return checksum(segments);
    }

    fn checksum(segments: []Segment) u64 {
        var sum: u64 = 0;
        for (segments) |segment| {
            switch (segment) {
                .free => {},
                .file => |data| {
                    for (data.pos..data.pos + data.len) |i| {
                        sum += i * data.id;
                    }
                },
            }
        }
        return sum;
    }

    pub fn format(self: *Disk, comptime _: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
        for (self.segments.items) |segment| {
            switch (segment) {
                .file => |data| {
                    for (0..data.len) |_| try w.print("{d}", .{data.id});
                },
                .free => |data| {
                    for (0..data.len) |_| try w.writeByte('.');
                },
            }
        }
    }
};

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var input_file = std.fs.cwd().openFile("day09/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    const input = try input_file.readToEndAlloc(ally, 20001);
    defer ally.free(input);

    // part 1
    {
        var disk = try Disk.initParse(ally, input);
        defer disk.deinit();

        const answer_p1 = try disk.compact();
        try stdout.print("Part 1: {d}\n", .{answer_p1});
    }

    // part 2
    {
        var disk = try Disk.initParse(ally, input);
        defer disk.deinit();

        const answer_p2 = try disk.compactNoFragmentation();
        try stdout.print("Part 2: {d}\n", .{answer_p2});
    }
}

test "part 1" {
    var disk = try Disk.initParse(testing.allocator, example);
    defer disk.deinit();
    const checksum = try disk.compact();
    try expectEqual(1928, checksum);
}

test "part 2" {
    var disk = try Disk.initParse(testing.allocator, example);
    defer disk.deinit();
    const checksum = try disk.compactNoFragmentation();
    _ = checksum;
    // try expectEqual(2858, checksum);
}
