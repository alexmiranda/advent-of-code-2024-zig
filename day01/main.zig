const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;
const heap = std.heap;
const fmt = std.fmt;
const io = std.io;
const example = @embedFile("example.txt");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("Memory leak!", .{});
    };
    const ally = gpa.allocator();

    const stdout_file = io.getStdOut().writer();
    var bw = io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!

    const path = "day01/input.txt";
    var input_file = std.fs.cwd().openFile(path, .{}) catch |err|
        switch (err) {
        error.FileNotFound, error.AccessDenied => std.debug.panic("Input file is missing", .{}),
        else => std.debug.panic("Failed to open file: {s}", .{path}),
    };
    defer input_file.close();

    const reader = input_file.reader();
    const part_1 = try part1(ally, reader);

    const stdout = bw.writer();
    try stdout.print("Part 1: {d}\n", .{part_1});
}

fn part1(ally: mem.Allocator, reader: anytype) !u32 {
    var left_locations = std.ArrayList(i32).init(ally);
    defer left_locations.deinit();

    var right_locations = std.ArrayList(i32).init(ally);
    defer right_locations.deinit();

    var buf: [14]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |read| {
        if (read.len == 0) continue;
        var it = mem.tokenizeScalar(u8, read, ' ');
        const lval = fmt.parseInt(i32, it.next().?, 10) catch @panic("problem with input: could not parse number");
        try left_locations.append(lval);
        const rval = fmt.parseInt(i32, it.next().?, 10) catch @panic("problem with input: could not parse number");
        try right_locations.append(rval);
    }

    mem.sort(i32, left_locations.items, {}, std.sort.asc(i32));
    mem.sort(i32, right_locations.items, {}, std.sort.asc(i32));

    var total_distance: u32 = 0;
    for (left_locations.items, right_locations.items) |lhs, rhs| {
        total_distance += @abs(lhs - rhs);
    }
    return total_distance;
}

test "part 1" {
    var fbs = io.fixedBufferStream(example);
    try expectEqual(11, part1(testing.allocator, fbs.reader()));
}

test "part 2" {
    return error.SkipZigTest;
}
