const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    const input_file =
        std.fs.cwd().openFile("day03/input.txt", .{}) catch |err| {
        switch (err) {
            error.FileNotFound => panic("Input file is missing", .{}),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var buf: [19813]u8 = undefined;
    const read = try input_file.readAll(&buf);
    const answer_p1 = compute(buf[0..read]);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

fn compute(buffer: []const u8) u32 {
    var sum: u32 = 0;
    var start: usize = 0;
    // first we need to find the beginnig of the expr mul(
    while (std.mem.indexOfPos(u8, buffer, start, "mul(")) |pos| {
        print("pos: {d}\n", .{pos});
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

test "part 1" {
    try expectEqual(161, compute(example));
}

test "part 2" {
    return error.SkipZigTest;
}
