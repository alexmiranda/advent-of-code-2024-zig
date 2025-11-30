const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    const input_file =
        std.fs.cwd().openFile("day03/input.txt", .{ .mode = .read_only }) catch |err| {
            switch (err) {
                error.FileNotFound => panic("Input file is missing", .{}),
                else => panic("{any}", .{err}),
            }
        };
    defer input_file.close();

    var buf: [19813]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &buf);
    const read = try reader.interface.take(buf.len);
    const answer_p1 = compute(read);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = computeEnabledOnly(read);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn compute(buffer: []const u8) u32 {
    var sum: u32 = 0;
    var start: usize = 0;
    // first we need to find the beginnig of the expr mul(
    while (std.mem.indexOfPos(u8, buffer, start, "mul(")) |pos| {
        // move the start to the found position
        start = pos;
        // print("pos: {d} match: {s}\n", .{ pos, buffer[start .. start + 4 + @min(7, buffer.len - pos)] });

        // we now have to search for the closing bracket in the next 7 positions
        const end = blk: {
            const end_pos = std.mem.indexOfScalarPos(u8, buffer[start .. start + @min(12, buffer.len - pos)], 7, ')') orelse {
                start += 4;
                continue;
            };
            break :blk start + end_pos + 1;
        };
        assert(end > start + 7);

        // guarantee that start will become end when we continue
        defer start = end;

        const inner = buffer[start + 4 .. end - 1];
        var it = std.mem.splitScalar(u8, inner, ',');

        // parse the first number
        const s1 = it.next() orelse continue;
        const n1 = std.fmt.parseInt(u32, s1, 10) catch continue;

        // parse the second number
        const s2 = it.next() orelse continue;
        const n2 = std.fmt.parseInt(u32, s2, 10) catch continue;

        // check that there's nothing else in the expression
        if (it.peek()) |_| continue;

        // sum up
        sum += n1 * n2;
    }
    return sum;
}

fn computeEnabledOnly(buffer: []const u8) u32 {
    var it = std.mem.tokenizeSequence(u8, buffer, "do");
    var sum: u32 = 0;
    var enabled = true;
    while (it.next()) |tok| {
        if (std.mem.startsWith(u8, tok, "()")) enabled = true;
        if (std.mem.startsWith(u8, tok, "n't()")) enabled = false;
        if (enabled) sum += compute(tok);
    }
    return sum;
}

test "part 1" {
    try expectEqual(161, compute(example1));
}

test "part 2" {
    try expectEqual(48, computeEnabledOnly(example2));
}
