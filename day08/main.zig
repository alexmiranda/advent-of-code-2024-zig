const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

fn Grid(comptime width: usize) type {
    const Coord = struct { row: isize, col: isize };

    return struct {
        ally: std.mem.Allocator,
        antennas: [62]?std.ArrayListUnmanaged(Coord),

        fn initParse(ally: std.mem.Allocator, reader: anytype) !@This() {
            var grid: @This() = .{
                .ally = ally,
                .antennas = [_]?std.ArrayListUnmanaged(Coord){null} ** 62,
            };
            errdefer grid.deinit();

            var buf: [width + 1]u8 = undefined;
            var row: isize = 0;
            while (true) : (row += 1) {
                const read = try reader.read(&buf);
                if (read == 0) break;
                for (buf[0..read], 0..) |tile, col| {
                    if (tile == '.' or tile == '\n') continue;
                    assert(std.ascii.isAlphanumeric(tile));
                    const i = switch (tile) {
                        'A'...'Z' => tile - 'A',
                        'a'...'z' => 26 + tile - 'a',
                        '0'...'9' => 26 * 2 + tile - '0',
                        else => unreachable,
                    };
                    grid.antennas[i] = blk: {
                        var array = grid.antennas[i] orelse try std.ArrayListUnmanaged(Coord).initCapacity(ally, 2);
                        errdefer array.deinit(ally);
                        try array.append(ally, .{ .row = row, .col = @intCast(col) });
                        break :blk array;
                    };
                }
            }
            return grid;
        }

        fn deinit(self: *@This()) void {
            for (self.antennas) |antennas| {
                if (antennas) |*array| @constCast(array).deinit(self.ally);
            }
        }

        fn countAntinodes(self: *@This()) !u64 {
            var antinodes = std.AutoHashMap(Coord, void).init(self.ally);
            defer antinodes.deinit();

            for (self.antennas) |antennas| {
                const coords = antennas orelse continue;
                if (coords.items.len < 2) continue;
                for (coords.items, 0..) |lhs, i| {
                    for (coords.items, 0..) |rhs, j| {
                        if (i == j) continue;
                        const delta_row = lhs.row - rhs.row;
                        const delta_col = lhs.col - rhs.col;
                        const antinode: Coord = .{ .row = lhs.row + delta_row, .col = lhs.col + delta_col };
                        try addIfWithinBounds(antinode, &antinodes);
                    }
                }
            }

            return antinodes.count();
        }

        fn addIfWithinBounds(coord: Coord, set: *std.AutoHashMap(Coord, void)) !void {
            if (coord.row < 0 or coord.row >= width) return;
            if (coord.col < 0 or coord.col >= width) return;
            try set.put(coord, {});
        }
    };
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var input_file = std.fs.cwd().openFile("day08/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    var br = std.io.bufferedReader(input_file.reader());
    var grid = try Grid(50).initParse(ally, br.reader());
    defer grid.deinit();

    const answer_p1 = try grid.countAntinodes();
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

test "part 1" {
    var fbs = std.io.fixedBufferStream(example);
    var grid = try Grid(12).initParse(testing.allocator, fbs.reader());
    defer grid.deinit();
    try expectEqual(14, grid.countAntinodes());
}

test "part 2" {
    return error.SkipZigTest;
}
