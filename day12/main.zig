const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const minInt = std.math.minInt;
const maxInt = std.math.maxInt;
const example1 = @embedFile("example1.txt");
const example2 = @embedFile("example2.txt");
const example3 = @embedFile("example3.txt");
const example4 = @embedFile("example4.txt");

const Garden = struct {
    ally: Allocator,
    plots: Map,

    const Plot = struct { isize, isize };
    const Map = std.AutoHashMapUnmanaged(Plot, u8);
    const Region = std.AutoHashMapUnmanaged(Plot, void);

    fn initParse(ally: Allocator, buffer: []const u8) !Garden {
        var plots: Map = .empty;
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

    fn fencingPrice(self: *Garden, with_bulk_discount: bool) !usize {
        const ally = self.ally;

        // clone plots so we don't mutate the map
        var plots = try self.plots.clone(ally);
        defer plots.deinit(ally);

        // region holds all plots belonging to the current region
        var region = Region{};
        defer region.deinit(ally);

        // iterate over all regions
        var total: usize = 0;
        while (plots.size > 0) {
            defer region.clearRetainingCapacity();

            const head = blk: {
                var iter = plots.iterator();
                break :blk iter.next().?;
            };
            const region_name = head.value_ptr.*;

            // flood fill and move plots from the copy of plots to the region
            try floodfill(ally, &plots, &region, head.key_ptr, region_name);

            // add up region fencing price
            const area = region.count();

            // print("=== region: {c} ===\n", .{region_name});
            if (with_bulk_discount) {
                const sides = try countSides(ally, &region, true);
                // print("A region of {c} plants with price {d} * {d} = {d}\n", .{ region_name, area, sides, area * sides });
                total += area * sides;
            } else {
                const perimeter = calculatePerimeter(&region);
                // print("A region of {c} plants with price {d} * {d} = {d}\n", .{ region_name, area, perimeter, area * perimeter });
                total += area * perimeter;
            }
        }
        return total;
    }

    /// finds all plots connected to the given key argument and copy them over from the map to region.
    fn floodfill(ally: Allocator, map: *Map, region: *Region, key: *Plot, match: u8) !void {
        var adjacent_plots: [4]Plot = undefined;

        // make a copy of the plot row and col
        const plot = key.*;

        // we remove the plot using a pointer to avoid double look up
        map.removeByPtr(key);

        // and add the plot of the region
        try region.put(ally, plot, {});

        // we iterate over every neighbouring plot
        for (neighbours(&adjacent_plots, plot)) |neighbour| {
            // if an entry is found, then we haven't visited that plot yet
            if (map.getEntry(neighbour)) |kv| {
                // continue if the found plot doesn't belong to the region
                if (kv.value_ptr.* != match) continue;

                // repeat the flood fill recursively
                try floodfill(ally, map, region, kv.key_ptr, match);

                // and add the neighbour to the region
                try region.put(ally, neighbour, {});
            }
        }
    }

    /// calculates the perimeter of a whole region by finding adjacent plots that don't belong to the region.
    fn calculatePerimeter(region: *Region) usize {
        var perimeter: usize = 0;
        var adjacent_plots: [4]Plot = undefined;
        var iter = region.keyIterator();
        while (iter.next()) |plot| {
            const adjacents = neighbours(&adjacent_plots, plot.*);
            perimeter += 4 - adjacents.len;
            for (adjacents) |adjacent| {
                if (!region.contains(adjacent)) {
                    perimeter += 1;
                }
            }
        }
        return perimeter;
    }

    /// calculates the number of sides of a whole region by counting the number of corners
    fn countSides(ally: Allocator, region: *Region, count_inside: bool) !usize {
        var count: usize = 0;

        var inside_area_map = Map{};
        defer inside_area_map.deinit(ally);

        // fill the inside area map
        if (count_inside) {
            try fillInsideArea(ally, &inside_area_map, region);
        }

        // first we need to count the number of outside corners
        var iter = region.keyIterator();
        while (iter.next()) |key_ptr| {
            const plot = key_ptr.*;

            // we check all 8 adjacent plots...
            var corners: u8 = 0;
            var delta_row: isize = -1;
            while (delta_row <= 1) : (delta_row += 1) {
                var delta_col: isize = -1;
                while (delta_col <= 1) : (delta_col += 1) {
                    if (delta_row == 0 and delta_col == 0) continue;
                    // if the plot is in region, its bit will be set to 0
                    // but if it's outside of the region, it will be set to 1
                    corners <<= 1;
                    const neighbour: Plot = .{ plot.@"0" + delta_row, plot.@"1" + delta_col };
                    if (!region.contains(neighbour) and !inside_area_map.contains(neighbour)) {
                        corners |= 1;
                    }
                }
            }

            // corner selection masks
            const tl_corner: u8 = 0b11010000;
            const tr_corner: u8 = 0b01101000;
            const bl_corner: u8 = 0b00010110;
            const br_corner: u8 = 0b00001011;

            // convex and concave flags
            const tl_convex: u8 = tl_corner;
            const tl_concave: u8 = 0b10000000;
            const tr_convex: u8 = tr_corner;
            const tr_concave: u8 = 0b00100000;
            const bl_convex: u8 = bl_corner;
            const bl_concave: u8 = 0b00000100;
            const br_convex: u8 = br_corner;
            const br_concave: u8 = 0b00000001;

            // count all corners, either convex or concave
            if (corners & tl_corner == tl_convex) {
                count += 1;
                // print("TL", .{});
            }
            if (corners & tl_corner == tl_concave) {
                count += 1;
                // print("Tl", .{});
            }
            if (corners & tr_corner == tr_convex) {
                count += 1;
                // print("TR", .{});
            }
            if (corners & tr_corner == tr_concave) {
                count += 1;
                // print("Tr", .{});
            }
            if (corners & bl_corner == bl_convex) {
                count += 1;
                // print("BL", .{});
            }
            if (corners & bl_corner == bl_concave) {
                count += 1;
                // print("Bl", .{});
            }
            if (corners & br_corner == br_convex) {
                count += 1;
                // print("BR", .{});
            }
            if (corners & br_corner == br_concave) {
                count += 1;
                // print("Br", .{});
            }
            // print("\n", .{});

            // print("({d}, {d}) = {b:0>8} [count={d}]\n", .{ plot.@"0", plot.@"1", corners, count });
        }

        // return only the outside corners count if counting inside of a larger region
        if (!count_inside) return count;

        var inside_region = Region{};
        defer inside_region.deinit(ally);

        // determine the number of inside corners
        while (inside_area_map.size > 0) {
            defer inside_region.clearRetainingCapacity();

            const head = blk: {
                var iter2 = inside_area_map.iterator();
                break :blk iter2.next().?;
            };

            // flood fill and move plots from the inside area to the inside region
            try floodfill(ally, &inside_area_map, &inside_region, head.key_ptr, '#');

            // add the numbers of sides of the nested area
            count += try countSides(ally, &inside_region, false);
        }

        return count;
    }

    /// Determines the garden plots that are found entirely inside of a region
    fn fillInsideArea(ally: Allocator, inside_area: *Map, region: *Region) !void {
        var min_row: isize = maxInt(isize);
        var max_row: isize = minInt(isize);
        var min_col: isize = maxInt(isize);
        var max_col: isize = minInt(isize);

        // determine the min/max row and col of the whole region
        var iter = region.keyIterator();
        while (iter.next()) |key_ptr| {
            const plot = key_ptr.*;
            min_row = @min(min_row, plot.@"0");
            max_row = @max(max_row, plot.@"0");
            min_col = @min(min_col, plot.@"1");
            max_col = @max(max_col, plot.@"1");
        }

        // ensure we have correct box area
        assert(max_row >= min_row);
        assert(max_col >= min_col);

        // the region must be at least 3x3 to have fences inside
        if (max_row - min_row < 3 or max_col - min_col < 3) return;

        // fill the inside area with all the plots enclosed by the region
        var candidates = Region{};
        defer candidates.deinit(ally);

        // queue of plots to visit
        var q: std.ArrayList(Plot) = .empty;
        defer q.deinit(ally);

        var inside = false;
        var row = min_row;
        while (row < max_row) : (row += 1) {
            var col = min_col;
            outer_loop: while (col < max_col) : (col += 1) {
                assert(candidates.size == 0);
                assert(q.items.len == 0);
                const is_present = region.contains(.{ row, col });
                if (is_present and !inside) {
                    inside = true;
                }

                if (inside and !is_present) {
                    const candidate: Plot = .{ row, col };
                    if (inside_area.contains(candidate)) continue;
                    try candidates.put(ally, candidate, {});

                    // bfs
                    try q.append(ally, candidate);
                    while (q.pop()) |curr| {
                        // check if it escapes the box area
                        if (curr.@"0" <= min_row or curr.@"0" >= max_row or curr.@"1" <= min_col or curr.@"1" >= max_col) {
                            q.clearRetainingCapacity();
                            candidates.clearRetainingCapacity();
                            continue :outer_loop;
                        }

                        // visit each neighbour and skip if it's in the region or already a candidate
                        var buf: [4]Plot = undefined;
                        for (neighbours(&buf, curr)) |adjacent| {
                            if (region.contains(adjacent)) continue;
                            if (try candidates.fetchPut(ally, adjacent, {})) |_| continue;
                            try q.append(ally, adjacent);
                        }
                    }

                    // if it didn't escape the box area, we know it's a nested region
                    // so we commit it to the inside area map.
                    var iter_candidates = candidates.keyIterator();
                    while (iter_candidates.next()) |key_ptr| {
                        try inside_area.put(ally, key_ptr.*, '#');
                        candidates.removeByPtr(key_ptr);
                    }
                }
            }
            inside = false;
        }
    }

    /// finds all neighbouring plots
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
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day12/input.txt", .{ .mode = .read_only }) catch |err|
        {
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
    const input = try reader.interface.readAlloc(ally, 19741);
    defer ally.free(input);

    var garden = try Garden.initParse(ally, input);
    defer garden.deinit();

    const answer_p1 = try garden.fencingPrice(false);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const answer_p2 = try garden.fencingPrice(true);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

test "part 1 - example 1" {
    var garden = try Garden.initParse(testing.allocator, example1);
    defer garden.deinit();
    const price = try garden.fencingPrice(false);
    try expectEqual(140, price);
}

test "part 1 - example 2" {
    var garden = try Garden.initParse(testing.allocator, example2);
    defer garden.deinit();
    const price = try garden.fencingPrice(false);
    try expectEqual(1930, price);
}

test "part 2 - example 1" {
    var garden = try Garden.initParse(testing.allocator, example1);
    defer garden.deinit();
    const price = try garden.fencingPrice(true);
    try expectEqual(80, price);
}

test "part 2 - example 2" {
    var garden = try Garden.initParse(testing.allocator, example2);
    defer garden.deinit();
    const price = try garden.fencingPrice(true);
    try expectEqual(1206, price);
}

test "part 2 - example 3" {
    var garden = try Garden.initParse(testing.allocator, example3);
    defer garden.deinit();
    const price = try garden.fencingPrice(true);
    try expectEqual(236, price);
}

test "part 2 - example 4" {
    var garden = try Garden.initParse(testing.allocator, example4);
    defer garden.deinit();
    const price = try garden.fencingPrice(true);
    try expectEqual(368, price);
}
