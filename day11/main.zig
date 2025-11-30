const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");

fn parseInput(ally: std.mem.Allocator, reader: *std.Io.Reader) ![]u64 {
    var list: std.ArrayList(u64) = try .initCapacity(ally, 8);
    defer list.deinit(ally);

    const line = try reader.takeDelimiterExclusive('\n');
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    while (it.next()) |tok| {
        const s = std.mem.trimEnd(u8, tok, "\n");
        const n = try std.fmt.parseInt(u64, s, 10);
        try list.append(ally, n);
    }

    return try list.toOwnedSlice(ally);
}

fn blink(ally: std.mem.Allocator, list: []u64, comptime n: usize) !usize {
    var stones = std.AutoHashMap(u64, usize).init(ally);
    defer stones.deinit();

    // initialise the map of all stones: stone => count
    for (list) |stone| {
        const gop = try stones.getOrPut(stone);
        gop.value_ptr.* = if (gop.found_existing) gop.value_ptr.* + 1 else 1;
    }

    // repeat n times
    for (0..n) |_| {
        // copy all the values from stones to current and set the map to an empty state
        var curr = stones.move();
        defer curr.clearAndFree();

        // iterate over all current stones
        var it = curr.iterator();
        while (it.next()) |kv| {
            const key = kv.key_ptr.*;
            const val = kv.value_ptr.*;

            // rule 1: If the stone is engraved with the number 0, it is replaced by a stone engraved with the number 1
            if (key == 0) {
                const gop = try stones.getOrPut(1);
                gop.value_ptr.* = (if (gop.found_existing) gop.value_ptr.* else 0) + val;
                continue;
            }

            // check how many digits there are in the stone's number
            const digits = std.math.log10_int(key) + 1;
            if (digits & 1 == 0) {
                // rule 2: If the stone is engraved with a number that has an even number of digits, it is replaced by
                // two stones. The left half of the digits are engraved on the new left stone, and the right half of
                // the digits are engraved on the new right stone
                inline for (split(key)) |split_val| {
                    const gop = try stones.getOrPut(split_val);
                    gop.value_ptr.* = (if (gop.found_existing) gop.value_ptr.* else 0) + val;
                }
            } else {
                // rule 3: If none of the other rules apply, the stone is replaced by a new stone; the old stone's
                // number multiplied by 2024 is engraved on the new stone
                const next_val = key * 2024;
                const gop = try stones.getOrPut(next_val);
                gop.value_ptr.* = (if (gop.found_existing) gop.value_ptr.* else 0) + val;
            }
        }
    }

    // sum up all the stones
    var count: usize = 0;
    var values = stones.valueIterator();
    while (values.next()) |val| count += val.*;
    return count;
}

fn split(stone: u64) struct { u64, u64 } {
    const digits = std.math.log10_int(stone) + 1;
    assert(digits & 1 == 0);
    const x = std.math.pow(u64, 10, digits / 2);
    const right: u64 = stone % x;
    const left: u64 = (stone - right) / x;
    return .{ left, right };
}

test split {
    try std.testing.expectEqualSlices(u64, &[_]u64{ 1, 0 }, &split(10));
    try std.testing.expectEqualSlices(u64, &[_]u64{ 9, 9 }, &split(99));
    try std.testing.expectEqualSlices(u64, &[_]u64{ 20, 24 }, &split(2024));
}

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

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

    var read_buffer: [1024]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buffer);
    const input = try parseInput(ally, &reader.interface);
    defer ally.free(input);

    const answer_p1 = try blink(ally, input, 25);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = try blink(ally, input, 75);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

test "part 1 - example 1" {
    var reader: std.Io.Reader = .fixed(example1);
    const input = try parseInput(testing.allocator, &reader);
    defer testing.allocator.free(input);
    const stones = try blink(testing.allocator, input, 1);
    try expectEqual(7, stones);
}

test "part 1 - example 2" {
    var reader: std.Io.Reader = .fixed(example2);
    const input = try parseInput(testing.allocator, &reader);
    defer testing.allocator.free(input);
    try expectEqual(22, blink(testing.allocator, input, 6));
    try expectEqual(55312, blink(testing.allocator, input, 25));
}
