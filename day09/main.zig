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
    free: packed struct { pos: u64, len: u8, _id: u64 = 0 },
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
        const segments = self.segments.items;
        var left: usize = 1;
        var right: usize = self.segments.items.len - 1;
        outer: while (left < right) {
            // find the first available free space
            const free = inner: while (left < right) : (left += 1) {
                switch (segments[left]) {
                    .free => |*data| break data,
                    .file => continue :inner,
                }
            } else break :outer;

            // find the right-most file
            const file = inner: while (right > left) : (right -= 1) {
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

        var checksum: usize = 0;
        for (segments) |segment| {
            checksum += switch (segment) {
                .free => 0,
                .file => |data| blk: {
                    var sum: usize = 0;
                    for (data.pos..data.pos + data.len) |i| {
                        sum += i * data.id;
                    }
                    break :blk sum;
                },
            };
        }
        return checksum;
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

    var disk = try Disk.initParse(ally, input);
    defer disk.deinit();
    const answer_p1 = try disk.compact();

    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

test "part 1" {
    var disk = try Disk.initParse(testing.allocator, example);
    defer disk.deinit();
    const checksum = try disk.compact();
    try expectEqual(1928, checksum);
}

test "part 2" {
    return error.SkipZigTest;
}
