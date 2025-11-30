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

const PositionSet = std.AutoHashMapUnmanaged(Position, void);

const State = struct { Position, Dir };
const Seen = std.AutoHashMapUnmanaged(State, void);

const LabMap = struct {
    ally: std.mem.Allocator,
    guard: Position,
    dir: Dir = .up,
    obstructions: PositionSet,
    width: u8,

    fn initParse(ally: std.mem.Allocator, s: []const u8) !LabMap {
        var obstructions: PositionSet = .empty;
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
        var visited: PositionSet = .empty;
        defer visited.deinit(self.ally);

        // the starting position counts as visited
        try visited.put(self.ally, self.guard, {});

        // we visit each tile keeping track of which positions we've visited before
        var curr_pos = self.guard;
        var curr_dir = self.dir;
        while (next(curr_pos, curr_dir, self.width, self.obstructions)) |state| {
            curr_pos, curr_dir = state;
            try visited.put(self.ally, curr_pos, {});
        }
        return visited.count();
    }

    fn trapPatrol(self: *LabMap) !usize {
        var seen = Seen{};
        defer seen.deinit(self.ally);

        // the starting position counts as seen
        try seen.put(self.ally, .{ self.guard, self.dir }, {});

        // used to keep track of which positions we placed an obstruction that wasn't already there
        var loop_checked: PositionSet = .empty;
        defer loop_checked.deinit(self.ally);

        // we visit each tile keeping track of which positions we've seen before
        var count: usize = 0;
        var curr_pos = self.guard;
        var curr_dir = self.dir;
        while (next(curr_pos, curr_dir, self.width, self.obstructions)) |state| {
            const next_pos, _ = state;

            // if we didn't check this position before, we check if placing an obstruction creates a loop
            const gop = try loop_checked.getOrPut(self.ally, next_pos);
            if (!gop.found_existing and try self.loops(curr_pos, next_pos, curr_dir, seen)) count += 1;

            // keep track of visited tiles and direction
            try seen.put(self.ally, state, {});
            curr_pos, curr_dir = state;
        }
        return count;
    }

    fn loops(self: *LabMap, curr_pos: Position, next_pos: Position, curr_dir: Dir, seen_so_far: Seen) !bool {
        // place an obstruction at the guard's next position
        var tentative_obstructions = try self.obstructions.clone(self.ally);
        defer tentative_obstructions.deinit(self.ally);
        try tentative_obstructions.put(self.ally, next_pos, {});

        // create a new set of seen tiles
        var seen = try seen_so_far.clone(self.ally);
        defer seen.deinit(self.ally);

        // we visit each tile from the current position and if a loop is detected, we return
        var tentative_pos = curr_pos;
        var tentative_dir = curr_dir;
        while (next(tentative_pos, tentative_dir, self.width, tentative_obstructions)) |state| {
            tentative_pos, tentative_dir = state;
            if (try seen.fetchPut(self.ally, .{ tentative_pos, tentative_dir }, {})) |_| {
                return true;
            }
        }

        // guard's left the lab, so no loop
        return false;
    }

    fn next(curr: Position, dir: Dir, width: u8, obstructions: PositionSet) ?State {
        const next_pos: Position, const next_dir: Dir = switch (dir) {
            .up => blk: {
                if (curr.y == 0) return null;
                const pos: Position = .{ .x = curr.x, .y = curr.y - 1 };
                break :blk .{ pos, .right };
            },
            .right => blk: {
                if (curr.x == width) return null;
                const pos: Position = .{ .x = curr.x + 1, .y = curr.y };
                break :blk .{ pos, .down };
            },
            .down => blk: {
                if (curr.y == width - 1) return null;
                const pos: Position = .{ .x = curr.x, .y = curr.y + 1 };
                break :blk .{ pos, .left };
            },
            .left => blk: {
                if (curr.x == 0) return null;
                const pos: Position = .{ .x = curr.x - 1, .y = curr.y };
                break :blk .{ pos, .up };
            },
        };
        if (obstructions.contains(next_pos)) {
            return next(curr, next_dir, width, obstructions);
        }
        return .{ next_pos, dir };
    }
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day06/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    var reader = std.fs.File.reader(input_file, &.{});
    const input = try reader.interface.allocRemaining(ally, .limited(20000));
    defer ally.free(input);

    var labmap = try LabMap.initParse(ally, input);
    defer labmap.deinit();

    const answer_p1 = try labmap.patrol();
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = try labmap.trapPatrol();
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

test "part 1" {
    var labmap = try LabMap.initParse(testing.allocator, example);
    defer labmap.deinit();
    const answer = try labmap.patrol();
    return expectEqual(41, answer);
}

test "part 2" {
    var labmap = try LabMap.initParse(testing.allocator, example);
    defer labmap.deinit();
    const answer = try labmap.trapPatrol();
    return expectEqual(6, answer);
}
