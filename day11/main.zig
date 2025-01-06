const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");

fn parseInput(ally: std.mem.Allocator, reader: anytype) ![]u64 {
    var list = try std.ArrayList(u64).initCapacity(ally, 8);
    defer list.deinit();

    var buf: [8]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, ' ')) |tok| {
        const s = std.mem.trimRight(u8, tok, "\n");
        const n = try std.fmt.parseInt(u64, s, 10);
        try list.append(n);
    }

    return try list.toOwnedSlice();
}

fn blink(ally: std.mem.Allocator, stones: []u64, comptime n: usize) !usize {
    const max_capacity = stones.len * std.math.pow(usize, 2, n);
    var list = try std.ArrayList(u64).initCapacity(ally, max_capacity);
    defer list.deinit();

    list.appendSliceAssumeCapacity(stones);
    // print("{any}\n", .{list.items});
    for (0..n) |_| {
        const len = list.items.len;
        for (list.items[0..len], 0..) |stone, i| {
            if (stone == 0) {
                list.items[i] = 1;
                // print("1. was: 0 is: 1\n", .{});
                continue;
            }

            const digits = std.math.log10_int(stone) + 1;
            if (digits & 1 == 0) {
                const x = std.math.pow(u64, 10, digits / 2);
                const right: u64 = stone % x;
                const left: u64 = (stone - right) / x;
                // print("2. was: {d} is: ({d}, {d})\n", .{ stone, left, right });
                list.items[i] = left;
                try list.append(right);
            } else {
                // print("3. was: {d} is: {d}\n", .{ stone, stone * 2024 });
                list.items[i] = stone * 2024;
            }
        }
        // print("{any}\n", .{list.items});
    }
    return list.items.len;
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var input_file = std.fs.cwd().openFile("day11/input.txt", .{ .mode = .read_only }) catch |err|
        {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    const input = try parseInput(ally, input_file.reader());
    defer ally.free(input);

    const answer_p1 = try blink(ally, input, 25);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

test "part 1 - example 1" {
    var fbs = std.io.fixedBufferStream(example1);
    const input = try parseInput(testing.allocator, fbs.reader());
    defer testing.allocator.free(input);
    const stones = try blink(testing.allocator, input, 1);
    try expectEqual(7, stones);
}

test "part 1 - example 2" {
    var fbs = std.io.fixedBufferStream(example2);
    const input = try parseInput(testing.allocator, fbs.reader());
    defer testing.allocator.free(input);
    try expectEqual(22, blink(testing.allocator, input, 6));
    try expectEqual(55312, blink(testing.allocator, input, 25));
}

test "part 2" {
    return error.SkipZigTest;
}
