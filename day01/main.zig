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
    var gpa: heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("Memory leak!", .{});
    };
    const ally = gpa.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    const path = "day01/input.txt";
    var input_file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err|
        switch (err) {
            error.FileNotFound, error.AccessDenied => std.debug.panic("Input file is missing", .{}),
            else => std.debug.panic("Failed to open file: {s}", .{path}),
        };
    defer input_file.close();

    var reader_buffer: [1024]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &reader_buffer);
    const part_1 = try distanceBetweenLists(ally, &reader.interface);

    try reader.seekTo(0);
    const part_2 = try similarityScore(ally, &reader.interface);

    try stdout.print("Part 1: {d}\n", .{part_1});
    try stdout.print("Part 2: {d}\n", .{part_2});
    try stdout.flush();
}

fn distanceBetweenLists(ally: mem.Allocator, reader: *std.Io.Reader) !u32 {
    var left_locations: std.ArrayList(i32) = .empty;
    defer left_locations.deinit(ally);

    var right_locations: std.ArrayList(i32) = .empty;
    defer right_locations.deinit(ally);

    while (reader.takeDelimiterExclusive('\n')) |read| {
        if (read.len == 0) break;
        var it = mem.tokenizeScalar(u8, read, ' ');
        const lval = fmt.parseInt(i32, it.next().?, 10) catch @panic("problem with input: could not parse number");
        try left_locations.append(ally, lval);
        const rval = fmt.parseInt(i32, it.next().?, 10) catch @panic("problem with input: could not parse number");
        try right_locations.append(ally, rval);
        reader.toss(1); // skip the newline
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    mem.sort(i32, left_locations.items, {}, std.sort.asc(i32));
    mem.sort(i32, right_locations.items, {}, std.sort.asc(i32));

    var total_distance: u32 = 0;
    for (left_locations.items, right_locations.items) |lhs, rhs| {
        total_distance += @abs(lhs - rhs);
    }
    return total_distance;
}

fn similarityScore(ally: mem.Allocator, reader: *std.Io.Reader) !u64 {
    var left_locations: std.ArrayList(i32) = .empty;
    defer left_locations.deinit(ally);

    var right_locations: std.AutoHashMap(i32, i32) = .init(ally);
    defer right_locations.deinit();

    while (reader.takeDelimiterExclusive('\n')) |read| {
        if (read.len == 0) break;
        var it = mem.tokenizeScalar(u8, read, ' ');
        const lval = fmt.parseInt(i32, it.next().?, 10) catch @panic("problem with input: could not parse number");
        try left_locations.append(ally, lval);
        const rval = fmt.parseInt(i32, it.next().?, 10) catch @panic("problem with input: could not parse number");
        const gop = try right_locations.getOrPut(rval);
        gop.value_ptr.* = if (gop.found_existing) gop.value_ptr.* + 1 else 1;
        reader.toss(1); // skip the newline
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    var similarity_score: u64 = 0;
    for (left_locations.items) |lhs| {
        similarity_score += @abs(lhs * (right_locations.get(lhs) orelse 0));
    }
    return similarity_score;
}

test "part 1" {
    var reader = std.Io.Reader.fixed(example);
    try expectEqual(11, distanceBetweenLists(testing.allocator, &reader));
}

test "part 2" {
    var reader = std.Io.Reader.fixed(example);
    try expectEqual(31, similarityScore(testing.allocator, &reader));
}
