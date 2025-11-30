const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");
const example2 = @embedFile("example2.txt");

fn Grid(comptime width: usize) type {
    const Coord = struct { row: isize, col: isize };

    return struct {
        ally: std.mem.Allocator,
        antennas: [62]?std.ArrayList(Coord),

        fn initParse(ally: std.mem.Allocator, reader: *std.Io.Reader) !@This() {
            var grid: @This() = .{
                .ally = ally,
                .antennas = [_]?std.ArrayList(Coord){null} ** 62,
            };
            errdefer grid.deinit();

            var row: isize = 0;
            while (reader.take(width)) |line| : (row += 1) {
                if (line.len == 0) break;
                reader.toss(1); // skip the newline
                for (line, 0..) |tile, col| {
                    if (tile == '.' or tile == '\n') continue;
                    assert(std.ascii.isAlphanumeric(tile));
                    const i = switch (tile) {
                        'A'...'Z' => tile - 'A',
                        'a'...'z' => 26 + tile - 'a',
                        '0'...'9' => 26 * 2 + tile - '0',
                        else => unreachable,
                    };
                    grid.antennas[i] = blk: {
                        var array = grid.antennas[i] orelse try std.ArrayList(Coord).initCapacity(ally, 2);
                        errdefer array.deinit(ally);
                        try array.append(ally, .{ .row = row, .col = @intCast(col) });
                        break :blk array;
                    };
                }
            } else |err| switch (err) {
                error.EndOfStream => {},
                else => return err,
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
                        _ = try addIfWithinBounds(antinode, &antinodes);
                    }
                }
            }

            return antinodes.count();
        }

        fn countAntinodesRevised(self: *@This()) !u64 {
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
                        // var antinode: Coord = .{ .row = lhs.row + delta_row, .col = lhs.col + delta_col };
                        var antinode: Coord = .{ .row = lhs.row, .col = lhs.col };
                        while (try addIfWithinBounds(antinode, &antinodes)) {
                            antinode = .{ .row = antinode.row + delta_row, .col = antinode.col + delta_col };
                        }
                    }
                }
            }

            return antinodes.count();
        }

        fn addIfWithinBounds(coord: Coord, set: *std.AutoHashMap(Coord, void)) !bool {
            if (coord.row < 0 or coord.row >= width) return false;
            if (coord.col < 0 or coord.col >= width) return false;
            try set.put(coord, {});
            return true;
        }
    };
}

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

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

    var read_buffer: [1024]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buffer);
    var grid = try Grid(50).initParse(ally, &reader.interface);
    defer grid.deinit();

    const answer_p1 = try grid.countAntinodes();
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = try grid.countAntinodesRevised();
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

test "part 1" {
    var reader: std.Io.Reader = .fixed(example);
    var grid = try Grid(12).initParse(testing.allocator, &reader);
    defer grid.deinit();
    try expectEqual(14, grid.countAntinodes());
}

test "part 2" {
    var reader: std.Io.Reader = .fixed(example);
    var grid = try Grid(12).initParse(testing.allocator, &reader);
    defer grid.deinit();
    try expectEqual(34, grid.countAntinodesRevised());
}

test "part 2 - example 2" {
    var reader: std.Io.Reader = .fixed(example2);
    var grid = try Grid(10).initParse(testing.allocator, &reader);
    defer grid.deinit();
    try expectEqual(9, grid.countAntinodesRevised());
}
