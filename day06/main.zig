const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

const Dir = enum {
    up,
    right,
    down,
    left,
};

const Position = struct {
    x: u8,
    y: u8,
};

const LabMap = struct {
    ally: std.mem.Allocator,
    guard: Position,
    dir: Dir = .up,
    obstructions: std.AutoHashMapUnmanaged(Position, void),
    width: u8,

    fn initParse(ally: std.mem.Allocator, s: []const u8) !LabMap {
        var obstructions = std.AutoHashMapUnmanaged(Position, void){};
        errdefer obstructions.deinit(ally);

        var guard: Position = undefined;

        var x: u8 = 0;
        var y: u8 = 0;
        for (s) |c| switch (c) {
            '.' => x += 1,
            '#' => {
                x += 1;
                try obstructions.put(ally, .{ .x = x, .y = y }, {});
            },
            '^' => {
                x += 1;
                guard.x = x;
                guard.y = y;
            },
            '\n' => {
                y += 1;
                x = 0;
            },
            else => unreachable,
        };

        // Assumption: the lab map is a square
        return .{ .ally = ally, .guard = guard, .obstructions = obstructions, .width = y - 1 };
    }

    fn deinit(self: *LabMap) void {
        self.obstructions.deinit(self.ally);
    }

    fn patrol(self: *LabMap) !usize {
        // print("patrol started with guard at {d}, {d} and width={d}\n", .{ self.guard.x, self.guard.y, self.width });
        var visited = std.AutoHashMapUnmanaged(Position, void){};
        defer visited.deinit(self.ally);
        try visited.put(self.ally, self.guard, {});
        while (self.nextPos()) |pos| {
            // print("guard at: {d}, {d} {s}\n", .{ pos.x, pos.y, @tagName(self.dir) });
            try visited.put(self.ally, pos, {});
        }
        return visited.count();
    }

    fn nextPos(self: *LabMap) ?Position {
        const next_pos: Position, const next_dir: Dir = switch (self.dir) {
            .up => blk: {
                if (self.guard.y == 0) return null;
                const pos: Position = .{ .x = self.guard.x, .y = self.guard.y - 1 };
                break :blk .{ pos, .right };
            },
            .right => blk: {
                if (self.guard.x == self.width) return null;
                const pos: Position = .{ .x = self.guard.x + 1, .y = self.guard.y };
                break :blk .{ pos, .down };
            },
            .down => blk: {
                if (self.guard.y == self.width - 1) return null;
                const pos: Position = .{ .x = self.guard.x, .y = self.guard.y + 1 };
                break :blk .{ pos, .left };
            },
            .left => blk: {
                if (self.guard.x == 0) return null;
                const pos: Position = .{ .x = self.guard.x - 1, .y = self.guard.y };
                break :blk .{ pos, .up };
            },
        };
        if (self.obstructions.contains(next_pos)) {
            self.dir = next_dir;
            return self.nextPos();
        }
        self.guard = next_pos;
        return self.guard;
    }
};

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var input_file = std.fs.cwd().openFile("day06/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    const input = try input_file.readToEndAlloc(ally, 20000);
    defer ally.free(input);

    var labmap = try LabMap.initParse(ally, input);
    defer labmap.deinit();

    const answer = try labmap.patrol();
    try stdout.print("Part 1: {d}\n", .{answer});
}

test "part 1" {
    var labmap = try LabMap.initParse(testing.allocator, example);
    defer labmap.deinit();
    const answer = try labmap.patrol();
    return expectEqual(41, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
