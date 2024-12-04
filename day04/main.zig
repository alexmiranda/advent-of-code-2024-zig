const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!
    const stdout = bw.writer();

    const input_file =
        std.fs.cwd().openFile("day04/input.txt", .{}) catch |err| {
        switch (err) {
            error.FileNotFound => panic("Input file is missing", .{}),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    var ally = gpa.allocator();

    const buffer = try input_file.readToEndAlloc(ally, 19741);
    defer ally.free(buffer);

    const grid = try parseInput(ally, buffer, 140);
    defer ally.free(grid);

    const answer_p1 = findXmas(grid);
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

fn parseInput(ally: std.mem.Allocator, buffer: []const u8, size_hint: usize) ![][]const u8 {
    var list = try std.ArrayList([]const u8).initCapacity(ally, size_hint);
    defer list.deinit();

    var start: usize = 0;
    while (std.mem.indexOfScalarPos(u8, buffer, start, '\n')) |pos| : (start = pos + 1) {
        if (pos - start == 0) break;
        try list.append(buffer[start..pos]);
    }
    return list.toOwnedSlice();
}

fn findXmas(grid: [][]const u8) usize {
    var count: usize = 0;
    if (grid.len == 0) return 0;
    for (0..grid.len) |row| {
        // while (row < grid.len) : (row += 1) {
        for (0..grid[0].len) |col| {
            // first we need to find an X
            if (grid[row][col] != 'X') continue;

            // then we check in all directions...
            var delta_row: isize = -1;
            while (delta_row <= 1) : (delta_row += 1) {
                var delta_col: isize = -1;
                dir_loop: while (delta_col <= 1) : (delta_col += 1) {
                    // skip: deltas are both 0
                    if (delta_row == 0 and delta_col == 0) continue;
                    // skip: not enough vertical space above
                    if (row < 3 and delta_row == -1) continue;
                    // skip: not enough vertival space below
                    if (grid.len - row < 4 and delta_row == 1) continue;
                    // skip: not enough horizontal space on the left
                    if (col < 3 and delta_col == -1) continue;
                    // skip: not enought horizontal space on the right
                    if (grid[0].len - col < 4 and delta_col == 1) continue;

                    // check if the positions all match the corresponding character in xmas
                    var r = row;
                    var c = col;
                    const xmas = "XMAS";
                    inline for (1..4) |i| {
                        r = @as(usize, @intCast(@as(isize, @intCast(r)) + delta_row));
                        c = @as(usize, @intCast(@as(isize, @intCast(c)) + delta_col));
                        if (grid[r][c] != xmas[i]) continue :dir_loop;
                    }
                    count += 1;
                }
            }
        }
    }
    return count;
}

test "part 1" {
    const ally = testing.allocator;
    const grid = try parseInput(ally, example, 10);
    defer ally.free(grid);

    try expectEqual(18, findXmas(grid));
}

test "part 2" {
    return error.SkipZigTest;
}
