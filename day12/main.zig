const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");

const Garden = struct {
    ally: std.mem.Allocator,
    plots: std.AutoHashMapUnmanaged(Plot, u8),

    const Plot = struct { isize, isize };

    fn initParse(ally: std.mem.Allocator, buffer: []const u8) !Garden {
        var plots = std.AutoHashMapUnmanaged(Plot, u8){};
        var row: isize = 0;
        var col: isize = 0;
        for (buffer) |c| {
            switch (c) {
                '\n' => {
                    row += 1;
                    col = 0;
                },
                else => {
                    try plots.put(ally, .{ row, col }, c);
                    col += 1;
                },
            }
        }
        return .{
            .ally = ally,
            .plots = plots,
        };
    }

    fn deinit(self: *Garden) void {
        self.plots.deinit(self.ally);
    }

    fn fencingPrice(self: *Garden) !usize {
        var region = std.AutoHashMapUnmanaged(Plot, void){};
        defer region.deinit(self.ally);

        // iterate over all regions
        var total: usize = 0;
        while (self.plots.size > 0) {
            defer region.clearRetainingCapacity();

            const head = blk: {
                var iter = self.plots.iterator();
                break :blk iter.next().?;
            };
            const region_name = head.value_ptr.*;

            // flood fill
            try self.floodfill(&region, head.key_ptr, region_name);
            const area = region.count();
            const perimeter = self.calculatePerimeter(&region, region_name);
            // print("A region of {c} plants with price {d} * {d} = {d}\n", .{ region_name, area, perimeter, area * perimeter });

            // add up region fencing price
            total += area * perimeter;
        }
        return total;
    }

    fn floodfill(self: *Garden, target: *std.AutoHashMapUnmanaged(Plot, void), key: *Plot, match: u8) !void {
        var adjacent_plots: [4]Plot = undefined;
        const plot = key.*;
        self.plots.removeByPtr(key);
        try target.put(self.ally, plot, {});
        for (neighbours(&adjacent_plots, plot)) |neighbour| {
            if (self.plots.getEntry(neighbour)) |kv| {
                if (kv.value_ptr.* != match) continue;
                try self.floodfill(target, kv.key_ptr, match);
                try target.put(self.ally, neighbour, {});
            }
        }
    }

    fn calculatePerimeter(self: *Garden, region: *std.AutoHashMapUnmanaged(Plot, void), match: u8) usize {
        var perimeter: usize = 0;
        var adjacent_plots: [4]Plot = undefined;
        var iter = region.keyIterator();
        while (iter.next()) |plot| {
            const adjacents = neighbours(&adjacent_plots, plot.*);
            perimeter += 4 - adjacents.len;
            for (adjacents) |adjacent| {
                if (region.contains(adjacent)) continue;
                const found = self.plots.get(adjacent) orelse 0;
                if (found != match) {
                    perimeter += 1;
                }
            }
        }
        return perimeter;
    }

    fn neighbours(buf: []Plot, plot: Plot) []Plot {
        const dirs: @Vector(8, isize) = .{ -1, 0, 0, 1, 1, 0, 0, -1 };
        var base: @Vector(8, isize) = undefined;
        inline for (&[_]usize{ 0, 2, 4, 6 }) |i| {
            base[i] = plot.@"0";
            base[i + 1] = plot.@"1";
        }
        const res = base + dirs;
        var slide: usize = 0;
        inline for (&[_]usize{ 0, 2, 4, 6 }) |i| {
            const row = res[i];
            const col = res[i + 1];
            if (row >= 0 and col >= 0) {
                buf[slide] = .{ row, col };
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

    var input_file = std.fs.cwd().openFile("day12/input.txt", .{ .mode = .read_only }) catch |err|
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

    const input = try input_file.readToEndAlloc(ally, 19741);
    defer ally.free(input);

    var garden = try Garden.initParse(ally, input);
    defer garden.deinit();

    const answer_p1 = try garden.fencingPrice();
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

test "part 1 - example 1" {
    var garden = try Garden.initParse(testing.allocator, example1);
    defer garden.deinit();
    const price = try garden.fencingPrice();
    try expectEqual(140, price);
}

test "part 1 - example 2" {
    var garden = try Garden.initParse(testing.allocator, example2);
    defer garden.deinit();
    const price = try garden.fencingPrice();
    try expectEqual(1930, price);
}

test "part 2" {
    return error.SkipZigTest;
}
