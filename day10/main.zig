const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");

const Map = struct {
    ally: std.mem.Allocator,
    grid: [][]const u8,
    width: isize,
    height: isize,

    const Position = struct {
        row: usize,
        col: usize,
    };

    const Trailhead = struct {
        start: Position,
        end: Position,
    };

    const Seen = std.AutoHashMap(Trailhead, void);

    fn initParse(ally: std.mem.Allocator, buffer: []const u8) !Map {
        var grid = std.ArrayListUnmanaged([]const u8){};
        defer grid.deinit(ally);

        var it = std.mem.tokenizeScalar(u8, buffer, '\n');
        while (it.next()) |tok| {
            try grid.append(ally, tok);
        }

        const width: isize = @bitCast(grid.items[0].len);
        const height: isize = @bitCast(grid.items.len);
        return .{
            .ally = ally,
            .grid = try grid.toOwnedSlice(ally),
            .width = width,
            .height = height,
        };
    }

    fn deinit(self: *Map) void {
        self.ally.free(self.grid);
    }

    fn totalScore(self: *Map) !usize {
        // for (self.grid) |row| print("{s}\n", .{row});
        var seen = Seen.init(self.ally);
        defer seen.deinit();
        for (self.grid, 0..) |row, row_index| {
            for (row, 0..) |col, col_index| {
                if (col == '0') {
                    const start: Position = .{ .row = row_index, .col = col_index };
                    try self.countTrailheads(start, start, &seen);
                }
            }
        }
        return seen.count();
    }

    fn countTrailheads(self: Map, start: Position, curr: Position, seen: *Seen) !void {
        const curr_val = self.grid[curr.row][curr.col];
        if (curr_val == '9') {
            try seen.put(.{ .start = start, .end = curr }, {});
            return;
        }

        const target = curr_val + 1;
        var buf: [4]Position = undefined;
        for (neighbours(&buf, curr, self.width, self.height)) |x| {
            const val = self.grid[x.row][x.col];
            if (val == target) {
                try self.countTrailheads(start, x, seen);
            }
        }
    }

    fn neighbours(buf: []Position, pos: Position, width: isize, height: isize) []Position {
        const delta_vec: @Vector(8, isize) = .{ -1, 0, 0, 1, 1, 0, 0, -1 };
        const orig_vec = blk: {
            var vec: @Vector(8, isize) = undefined;
            inline for (.{ 0, 2, 4, 6 }) |i| {
                vec[i] = @bitCast(pos.row);
                vec[i + 1] = @bitCast(pos.col);
            }
            break :blk vec;
        };
        const dest_vec = orig_vec + delta_vec;
        var slide: usize = 0;
        inline for (.{ 0, 2, 4, 6 }) |i| {
            if (dest_vec[i] >= 0 and dest_vec[i] < height and dest_vec[i + 1] >= 0 and dest_vec[i + 1] < width) {
                buf[slide].row = @bitCast(dest_vec[i]);
                buf[slide].col = @bitCast(dest_vec[i + 1]);
                slide += 1;
            }
        }
        return buf[0..slide];
    }
};

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var input_file = std.fs.cwd().openFile("day10/input.txt", .{ .mode = .read_only }) catch |err|
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

    const input = try input_file.readToEndAlloc(ally, 20001);
    defer ally.free(input);

    var map = try Map.initParse(ally, input);
    defer map.deinit();

    const answer_p1 = try map.totalScore();
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

test "part 1 - example 1" {
    var map = try Map.initParse(testing.allocator, example1);
    defer map.deinit();
    const score = try map.totalScore();
    try expectEqual(1, score);
}

test "part 1 - example 2" {
    var map = try Map.initParse(testing.allocator, example2);
    defer map.deinit();
    const score = try map.totalScore();
    try expectEqual(36, score);
}

test "part 2" {
    return error.SkipZigTest;
}
