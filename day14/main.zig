const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

const Pair = struct {
    x: i32,
    y: i32,

    fn initParse(buffer: []const u8) Pair {
        const sep = std.mem.indexOfScalar(u8, buffer, ',').?;
        const lhs, const rhs = .{ buffer[0..sep], buffer[sep + 1 ..] };
        const x = std.fmt.parseInt(i32, lhs, 10) catch unreachable;
        const y = std.fmt.parseInt(i32, rhs, 10) catch unreachable;
        return .{ .x = x, .y = y };
    }

    pub fn format(pair: Pair, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        _ = try writer.print("{d},{d}", .{ pair.x, pair.y });
    }
};

const Robot = struct { loc: Pair, vel: Pair };

fn Bathroom(comptime width: i32, comptime height: i32) type {
    if (width & 1 == 0) @compileError("width must be an odd number");
    if (height & 1 == 0) @compileError("height must be an odd number");
    return struct {
        ally: std.mem.Allocator,
        robots: std.AutoHashMapUnmanaged(Robot, void),

        const Self = @This();

        fn initParse(ally: std.mem.Allocator, buffer: []const u8) !Self {
            var robots = std.AutoHashMapUnmanaged(Robot, void){};
            errdefer robots.deinit(ally);

            var iter = std.mem.tokenizeAny(u8, buffer, " \n");
            while (iter.next()) |loc_str| {
                const loc = Pair.initParse(loc_str[2..]);
                const vel = Pair.initParse(iter.next().?[2..]);
                const robot: Robot = .{ .loc = loc, .vel = vel };
                // print("p={?} v={?}\n", .{ loc, vel });
                if (try robots.fetchPut(ally, robot, {})) |_| {
                    @panic("Oops");
                }
            }
            return .{ .ally = ally, .robots = robots };
        }

        fn deinit(self: *Self) void {
            self.robots.deinit(self.ally);
        }

        fn calculateSafetyFactor(self: *Self) usize {
            var quadrants: @Vector(4, usize) = @splat(0);
            const mid: Pair = .{ .x = @divFloor(width, 2), .y = @divFloor(height, 2) };
            var iter = self.robots.keyIterator();
            while (iter.next()) |key_ptr| {
                var robot = key_ptr.*;
                robot.loc.x = @mod(robot.loc.x + robot.vel.x * 100, width);
                robot.loc.y = @mod(robot.loc.y + robot.vel.y * 100, height);
                // print("p={?} v={?}\n", .{ robot.loc, robot.vel });
                if (robot.loc.x == mid.x or robot.loc.y == mid.y) continue;
                if (robot.loc.x < mid.x and robot.loc.y < mid.y) {
                    quadrants[0] += 1;
                } else if (robot.loc.x > mid.x and robot.loc.y < mid.y) {
                    quadrants[1] += 1;
                } else if (robot.loc.x < mid.x and robot.loc.y > mid.y) {
                    quadrants[2] += 1;
                } else if (robot.loc.x > mid.x and robot.loc.y > mid.y) {
                    quadrants[3] += 1;
                }
            }

            // print("{d}\n", .{quadrants});
            return @reduce(.Mul, quadrants);
        }

        fn simulate(self: *Self, writer: anytype) !void {
            var robots = self.robots.move();
            defer robots.deinit(self.ally);
            // try robots.ensureTotalCapacity(self.ally, width * height * 2);

            var next = std.AutoHashMapUnmanaged(Robot, void){};
            defer robots.deinit(self.ally);
            // try next.ensureTotalCapacity(self.ally, width * height * 2);

            for (1..10_000) |n| {
                var xs: [width]u8 = .{0} ** width;
                var ys: [height]u8 = .{0} ** height;
                var iter = robots.keyIterator();
                while (iter.next()) |key_ptr| {
                    var robot = key_ptr.*;
                    robot.loc.x = @mod(robot.loc.x + robot.vel.x, width);
                    robot.loc.y = @mod(robot.loc.y + robot.vel.y, height);
                    xs[@as(u32, @bitCast(robot.loc.x))] += 1;
                    ys[@as(u32, @bitCast(robot.loc.y))] += 1;
                    try next.put(self.ally, robot, {});
                    robots.removeByPtr(key_ptr);
                }
                std.mem.swap(std.AutoHashMapUnmanaged(Robot, void), &robots, &next);

                // detect frame around x-mas tree
                var score: usize = 0;
                for (xs ++ ys) |x| {
                    if (x >= 31) {
                        score += x;
                    }
                }

                if (score >= 31 * 4) {
                    var found: Self = .{ .ally = self.ally, .robots = robots.move() };
                    defer found.deinit();
                    try writer.print("N={d}\n", .{n});
                    try writer.print("{?}", .{found});
                    break;
                }
            }
        }

        pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            const size = width * height + height;
            var tiles: [size]u8 = .{'.'} ** size;
            var iter = self.robots.keyIterator();
            while (iter.next()) |key_ptr| {
                const robot = key_ptr.*;
                const pos: u32 = @bitCast(robot.loc.y * (width + 1) + robot.loc.x);
                tiles[pos] = switch (tiles[pos]) {
                    '.' => '1',
                    '1'...'8' => |c| c + 1,
                    '9', '#' => '#',
                    else => unreachable,
                };
            }
            var slide: u32 = @bitCast(width);
            for (0..height) |_| {
                tiles[slide] = '\n';
                slide += width + 1;
            }
            try writer.print("{s}", .{tiles});
        }
    };
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    var bathroom = blk: {
        var input_file = std.fs.cwd().openFile("day14/input.txt", .{ .mode = .read_only }) catch |err|
            {
            switch (err) {
                error.FileNotFound => @panic("Input file is missing"),
                else => panic("{any}", .{err}),
            }
        };
        defer input_file.close();

        const input = try input_file.readToEndAlloc(ally, 8324);
        defer ally.free(input);

        break :blk try Bathroom(101, 103).initParse(ally, input);
    };
    defer bathroom.deinit();

    const answer_p1 = bathroom.calculateSafetyFactor();
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try bathroom.simulate(stdout);
}

test "part 1" {
    var bathroom = try Bathroom(11, 7).initParse(testing.allocator, example);
    defer bathroom.deinit();
    const safety_factor = bathroom.calculateSafetyFactor();
    print("{?}\n", .{bathroom});
    try expectEqual(12, safety_factor);
}
