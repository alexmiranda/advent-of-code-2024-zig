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
    var gpa = heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) panic("Memory leak", .{});
    const ally = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!

    const path = "day02/input.txt";
    var input_file = std.fs.cwd().openFile(path, .{}) catch |err|
        switch (err) {
        error.FileNotFound, error.AccessDenied => std.debug.panic("Input file is missing", .{}),
        else => std.debug.panic("Failed to open file: {s}", .{path}),
    };
    defer input_file.close();

    const reader = input_file.reader();
    const part_1 = try countSafeReports(ally, reader, 23);

    try input_file.seekTo(0);
    const part_2 = try countSafeReportsRevised(ally, reader, 23);

    const stdout = bw.writer();
    try stdout.print("Part 1: {d}\n", .{part_1});
    try stdout.print("Part 2: {d}\n", .{part_2});
}

fn countSafeReports(ally: mem.Allocator, reader: anytype, max_line_length: usize) !usize {
    var bytes = try std.ArrayList(u8).initCapacity(ally, max_line_length);
    defer bytes.deinit();

    var levels = try std.ArrayList(u32).initCapacity(ally, 8);
    defer levels.deinit();

    var count: usize = 0;
    while (true) {
        defer bytes.clearRetainingCapacity();

        // first we read from the input line by line
        reader.streamUntilDelimiter(bytes.writer(), '\n', null) catch |err| {
            switch (err) {
                error.EndOfStream => break,
                else => panic("Error reading input: {any}", .{err}),
            }
        };
        if (bytes.items.len == 0) break;
        if (bytes.items[0] == '#') continue;

        // and then parse each report
        levels.clearRetainingCapacity();
        var it = mem.tokenizeScalar(u8, bytes.items, ' ');
        while (it.next()) |tok| {
            const n = fmt.parseInt(u32, tok, 10) catch panic("couldn't parse number: {s}", .{tok});
            levels.appendAssumeCapacity(n);
        }

        // if the report is safe, we count it
        if (safe(levels.items)) count += 1;
    }
    return count;
}

fn countSafeReportsRevised(ally: mem.Allocator, reader: anytype, max_line_length: usize) !usize {
    var bytes = try std.ArrayList(u8).initCapacity(ally, max_line_length);
    defer bytes.deinit();

    var levels = try std.ArrayList(u32).initCapacity(ally, 8);
    defer levels.deinit();

    var count: usize = 0;
    while (true) {
        defer bytes.clearRetainingCapacity();

        // first we read from the input line by line
        reader.streamUntilDelimiter(bytes.writer(), '\n', null) catch |err| {
            switch (err) {
                error.EndOfStream => break,
                else => panic("Error reading input: {any}", .{err}),
            }
        };
        if (bytes.items.len == 0) break;
        if (bytes.items[0] == '#') continue;

        // and then parse each report
        levels.clearRetainingCapacity();
        var it = mem.tokenizeScalar(u8, bytes.items, ' ');
        while (it.next()) |tok| {
            const n = fmt.parseInt(u32, tok, 10) catch panic("couldn't parse number: {s}", .{tok});
            levels.appendAssumeCapacity(n);
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
    }
    return count;
}

fn safe(levels: []u32) bool {
    var it = mem.window(u32, levels, 2, 1);
    const pair_head = it.next().?;
    var a = pair_head[0];
    var b = pair_head[1];
    if (b == a) return false;
    const is_increasing = b > a;
    if ((is_increasing and b - a > 3) or (!is_increasing and a - b > 3)) return false;
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
    var fbs = io.fixedBufferStream(example);
    try expectEqual(2, countSafeReports(testing.allocator, fbs.reader(), 9));
}

test "part 2" {
    var fbs = io.fixedBufferStream(example);
    try expectEqual(4, countSafeReportsRevised(testing.allocator, fbs.reader(), 9));
}
