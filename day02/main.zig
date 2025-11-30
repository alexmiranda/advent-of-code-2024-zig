const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const heap = std.heap;
const mem = std.mem;
const io = std.io;
const fmt = std.fmt;
const example = @embedFile("example.txt");

pub fn main() !void {
    var gpa: heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) panic("Memory leak", .{});
    const ally = gpa.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    const path = "day02/input.txt";
    var input_file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err|
        switch (err) {
            error.FileNotFound, error.AccessDenied => panic("Input file is missing", .{}),
            else => panic("Failed to open file: {s}", .{path}),
        };
    defer input_file.close();

    var reader_buffer: [1024]u8 = undefined;
    var reader = input_file.reader(&reader_buffer);
    const part_1 = try countSafeReports(ally, &reader.interface, 23);

    try reader.seekTo(0);
    const part_2 = try countSafeReportsRevised(ally, &reader.interface, 23);

    try stdout.print("Part 1: {d}\n", .{part_1});
    try stdout.print("Part 2: {d}\n", .{part_2});
    try stdout.flush();
}

fn countSafeReports(ally: mem.Allocator, reader: *std.Io.Reader, comptime max_line_length: usize) !usize {
    var buf: [max_line_length]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    var levels: std.ArrayList(u32) = try .initCapacity(ally, 8);
    defer levels.deinit(ally);

    var count: usize = 0;
    while (try reader.streamDelimiterEnding(&writer, '\n') > 0) {
        const line = writer.buffered();

        // parse each report
        levels.clearRetainingCapacity();
        var it = mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |tok| {
            const n = fmt.parseInt(u32, tok, 10) catch panic("couldn't parse number: {s}", .{tok});
            try levels.append(ally, n);
        }

        // if the report is safe, we count it
        if (safe(levels.items)) count += 1;

        _ = writer.consumeAll(); // reset writer
        reader.toss(1); // skip the newline
    }
    return count;
}

fn countSafeReportsRevised(ally: mem.Allocator, reader: *std.Io.Reader, comptime max_line_length: usize) !usize {
    var buf: [max_line_length]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    var levels: std.ArrayList(u32) = try .initCapacity(ally, 8);
    defer levels.deinit(ally);

    var count: usize = 0;
    while (try reader.streamDelimiterEnding(&writer, '\n') > 0) {
        const line = writer.buffered();

        // parse each report
        levels.clearRetainingCapacity();
        var it = mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |tok| {
            const n = fmt.parseInt(u32, tok, 10) catch panic("couldn't parse number: {s}", .{tok});
            try levels.append(ally, n);
        }

        // if the report is safe, we count it
        if (safe(levels.items)) {
            count += 1;
        } else {
            for (0..levels.items.len) |i| {
                const tentative_report = try mem.concat(ally, u32, &[_][]u32{ levels.items[0..i], levels.items[i + 1 ..] });
                defer ally.free(tentative_report);
                if (safe(tentative_report)) {
                    count += 1;
                    break;
                }
            }
        }

        _ = writer.consumeAll();
        reader.toss(1); // skip the newline
    }
    return count;
}

fn safe(levels: []u32) bool {
    var a = levels[0];
    var b = levels[1];
    const is_increasing = b > a;

    var it = mem.window(u32, levels, 2, 1);
    while (it.next()) |pair| {
        a = pair[0];
        b = pair[1];
        if (is_increasing) {
            if (a >= b) return false;
            const delta = b - a;
            if (delta > 3) return false;
        } else {
            if (b >= a) return false;
            const delta = a - b;
            if (delta > 3) return false;
        }
    }
    return true;
}

test "part 1" {
    var reader = std.Io.Reader.fixed(example);
    try expectEqual(2, countSafeReports(testing.allocator, &reader, 9));
}

test "part 2" {
    var reader = std.Io.Reader.fixed(example);
    try expectEqual(4, countSafeReportsRevised(testing.allocator, &reader, 9));
}
