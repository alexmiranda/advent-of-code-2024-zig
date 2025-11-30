const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

const Warehouse = struct {
    ally: std.mem.Allocator,
    tiles: std.AutoHashMapUnmanaged(i16, Tile),
    robot: i16,
    moves: []u8,

    const Tile = enum {
        wall,
        box,
    };

    fn initReader(ally: std.mem.Allocator, reader: anytype) !Warehouse {
        var tiles: std.AutoHashMapUnmanaged(i16, Tile) = .empty;
        errdefer tiles.deinit(ally);

        // read each char until a double new line is found
        var prev: u8 = undefined;
        var coord: i16 = 0;
        var robot: i16 = undefined;
        while (true) {
            const curr = try reader.readByte();
            switch (curr) {
                '\n' => {
                    if (prev == '\n') break;
                    coord += 100;
                    coord -= @mod(coord, 100);
                    prev = curr;
                    continue;
                },
                '#' => try tiles.put(ally, coord, .wall),
                'O' => try tiles.put(ally, coord, .box),
                '@' => robot = coord,
                '.' => {},
                else => unreachable,
            }
            coord += 1;
            prev = curr;
        }

        // read all moves
        var moves: std.ArrayList(u8) = .empty;
        var managed = moves.toManaged(ally);
        defer managed.deinit();
        try reader.readAllArrayList(&managed, 21000);

        return .{
            .ally = ally,
            .tiles = tiles,
            .robot = robot,
            .moves = try managed.toOwnedSlice(),
        };
    }

    fn deinit(self: *Warehouse) void {
        self.ally.free(self.moves);
        self.tiles.deinit(self.ally);
    }

    fn moveAroundUnpredictably(self: *Warehouse) !i32 {
        outer: for (self.moves) |move| {
            if (move == '\n') continue; // ignore new lines

            // each direction has an offset based on the GPS Coordinates
            const offset: i16 = switch (move) {
                '^' => -100,
                '>' => 1,
                'v' => 100,
                '<' => -1,
                else => panic("invalid move: {c}", .{move}),
            };

            // check the target
            const target = self.robot + offset;
            if (self.tiles.getEntry(target)) |entry| {
                switch (entry.value_ptr.*) {
                    // if the target is a wall, we don't move at all
                    .wall => continue,

                    // if the target is a box, we need to see if we can move that box
                    .box => {
                        // determine the next empty tile
                        var next_empty = target + offset;
                        while (self.tiles.get(next_empty)) |tile| : (next_empty += offset) {
                            switch (tile) {
                                .wall => continue :outer,
                                .box => {},
                            }
                        }

                        // if an empty tile is found, we move the box from the target position to
                        // the empty tile position
                        try self.tiles.put(self.ally, next_empty, .box);
                        self.tiles.removeByPtr(entry.key_ptr);
                    },
                }
            }

            // move the robot
            self.robot = target;
        }

        // sum all boxes' GPS coordinates
        var sum: i32 = 0;
        var iter = self.tiles.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* == .box) {
                sum += entry.key_ptr.*;
            }
        }

        return sum;
    }
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    var warehouse = blk: {
        var input_file = std.fs.cwd().openFile("day15/input.txt", .{ .mode = .read_only }) catch |err|
            {
                switch (err) {
                    error.FileNotFound => @panic("Input file is missing"),
                    else => panic("{any}", .{err}),
                }
            };
        defer input_file.close();

        var read_buffer: [1024]u8 = undefined;
        var reader = std.fs.File.reader(input_file, &read_buffer);
        break :blk try Warehouse.initReader(ally, reader.interface.adaptToOldInterface());
    };
    defer warehouse.deinit();

    const answer_p1 = try warehouse.moveAroundUnpredictably();
    try stdout.print("Part 1: {d}\n", .{answer_p1});
    try stdout.flush();
}

test "part 1" {
    var reader: std.Io.Reader = .fixed(example);
    var warehouse = try Warehouse.initReader(testing.allocator, reader.adaptToOldInterface());
    defer warehouse.deinit();
    const answer = try warehouse.moveAroundUnpredictably();
    try expectEqual(10092, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
