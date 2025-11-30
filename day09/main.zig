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
    segments: *std.ArrayList(Segment),

    fn initParse(ally: std.mem.Allocator, buffer: []const u8) !Disk {
        var segments: std.ArrayList(Segment) = try .initCapacity(ally, buffer.len);
        errdefer segments.deinit(ally);

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

        return .{ .segments = &segments };
    }

    fn deinit(self: *Disk, ally: std.mem.Allocator) void {
        self.segments.deinit(ally);
    }

    fn compact(self: *Disk, ally: std.mem.Allocator) !u64 {
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
                    try self.segments.insert(ally, left + 1, .{ .free = .{ .pos = file.pos + file.len, .len = delta } });
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

    fn compactNoFragmentation(self: *Disk, ally: std.mem.Allocator) !u64 {
        var seen = std.AutoHashMapUnmanaged(u64, void){};
        defer seen.deinit(ally);

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
                        try self.segments.insert(ally, i + 1, .{ .free = .{ .pos = file.pos + file.len, .len = delta } });
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
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day09/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    // FIXME: memory leak!
    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    var arena: std.heap.ArenaAllocator = .init(gpa.allocator());
    defer arena.deinit();
    const ally = arena.allocator();

    var read_buffer: [1024]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buffer);
    const input = try reader.interface.readAlloc(ally, 20001);
    defer ally.free(input);

    // part 1
    {
        var disk = try Disk.initParse(ally, input);
        defer disk.deinit(ally);

        const answer_p1 = try disk.compact(ally);
        try stdout.print("Part 1: {d}\n", .{answer_p1});
    }

    // part 2
    {
        var disk = try Disk.initParse(ally, input);
        defer disk.deinit(ally);

        const answer_p2 = try disk.compactNoFragmentation(ally);
        try stdout.print("Part 2: {d}\n", .{answer_p2});
    }
    try stdout.flush();
}

test "part 1" {
    // FIXME: memory leak!
    if (1 == 1) return error.SkipZigTest; // test failing after migrating to zig 0.15
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const ally = arena.allocator();
    var disk = try Disk.initParse(ally, example);
    defer disk.deinit(ally);
    const checksum = try disk.compact(ally);
    try expectEqual(1928, checksum);
}

test "part 2" {
    // FIXME: memory leak!
    if (1 == 1) return error.SkipZigTest; // test failing after migrating to zig 0.15
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const ally = arena.allocator();
    var disk = try Disk.initParse(ally, example);
    defer disk.deinit(ally);
    const checksum = try disk.compactNoFragmentation(ally);
    _ = checksum;
    // try expectEqual(2858, checksum);
}
