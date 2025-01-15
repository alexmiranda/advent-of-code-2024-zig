const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

const ClawMachine = struct {
    ax: i64,
    ay: i64,
    bx: i64,
    by: i64,
    px: i64,
    py: i64,

    fn initReader(reader: anytype) !?ClawMachine {
        // check for EOF, skips the first byte
        _ = reader.readBytesNoEof(1) catch return null;

        var buf: [12]u8 = undefined;
        const ax, const ay = try readXY(reader, &buf, '+');
        const bx, const by = try readXY(reader, &buf, '+');
        const px, const py = try readXY(reader, &buf, '=');

        // discard new line
        reader.skipBytes(1, .{}) catch {};

        return .{
            .ax = ax,
            .ay = ay,
            .bx = bx,
            .by = by,
            .px = px,
            .py = py,
        };
    }

    fn readXY(reader: anytype, buf: []u8, sep: u8) !struct { i64, i64 } {
        try reader.skipUntilDelimiterOrEof(sep);
        const x = try readParseInt(reader, buf, ',');
        try reader.skipUntilDelimiterOrEof(sep);
        const y = try readParseInt(reader, buf, '\n');
        return .{ x, y };
    }

    fn readParseInt(reader: anytype, buf: []u8, delim: u8) !i64 {
        if (try reader.readUntilDelimiterOrEof(buf, delim)) |tok| {
            return try std.fmt.parseInt(i64, tok, 10);
        }
        @panic("input error");
    }

    /// where n = number of times button a is pressed
    ///       m = number of times button b is pressed
    ///
    /// px = (ax * n) + (bx * m)
    /// py = (ay * n) + (by * m)
    ///
    /// =>
    ///
    /// concomittantely:
    /// n = (px - (bx * m)) / ax
    /// n = (py - (by * m)) / ay
    ///
    /// in other words:
    /// (px - (bx * m)) / ax = (py - (by * m)) / ay
    ///
    /// cross multiply:
    /// (px - (bx * m)) * ay = (py - (by * m)) * ax
    /// =>
    /// ay * py - ay * (bx * m) = ax * py - ax (by * m)
    ///
    /// m = ((ax * py) - (ay * px)) / ((ax * by) - (ay * bx)
<<<<<<< HEAD
    fn solve(self: @This()) ?u64 {
        const m = @divFloor((self.ax * self.py) - (self.ay * self.px), (self.ax * self.by) - (self.ay * self.bx));
        const n = @divFloor(self.px - (self.bx * m), self.ax);
        // we can only push each button a maximum of 100 times
        if (n > 100 or m > 100) return null;
        if ((self.ax * n) + (self.bx * m) == self.px and (self.ay * n) + (self.by * m) == self.py) {
            return @as(u64, @bitCast(3 * n + m));
        }
        return null; // ∞ INFINITE
    }
};

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var input_file = std.fs.cwd().openFile("day13/input.txt", .{ .mode = .read_only }) catch |err|
        {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var br = std.io.bufferedReader(input_file.reader());
    const reader = br.reader();
    var tokens: u64 = 0;
    while (try ClawMachine.initReader(reader)) |mach| {
        // print("{?}\n", .{mach});
        if (mach.solve()) |n| tokens += n;
    }

    try stdout.print("Part 1: {d}\n", .{tokens});
}

test "part 1" {
    var fbs = std.io.fixedBufferStream(example);
    const reader = fbs.reader();
    var tokens: u64 = 0;
    while (try ClawMachine.initReader(reader)) |mach| {
        // print("{?}\n", .{mach});
        if (mach.solve()) |n| tokens += n;
    }
    try expectEqual(480, tokens);
}

test "part 2" {
    return error.SkipZigTest;
}
