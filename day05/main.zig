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

    var input_file = std.fs.cwd().openFile("day05/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    const answer_p1 = try solve1(ally, input_file.reader());
    try stdout.print("Part 1: {d}\n", .{answer_p1});
}

fn solve1(ally: std.mem.Allocator, reader: anytype) !u32 {
    const Rule = struct { left: u8, right: u8 };
    var violations = std.AutoHashMap(Rule, void).init(ally);
    defer violations.deinit();

    var br = std.io.bufferedReader(reader);
    var r = br.reader();

    // first we read all the rules and create violation rules i.e. b > a
    var buf: [6]u8 = undefined;
    while (true) {
        const read = try r.readUntilDelimiter(&buf, '\n');
        if (read.len == 0) break;
        const a = try std.fmt.parseInt(u8, read[0..2], 10);
        const b = try std.fmt.parseInt(u8, read[3..], 10);
        try violations.put(.{ .left = b, .right = a }, {});
    }

    var line = try std.ArrayList(u8).initCapacity(ally, 100);
    defer line.deinit();

    var pages = std.ArrayList(u8).init(ally);
    defer pages.deinit();

    var sum: u32 = 0;
    outer: while (true) {
        defer line.clearRetainingCapacity();
        defer pages.clearRetainingCapacity();

        // read each line
        r.readUntilDelimiterArrayList(&line, '\n', line.capacity) catch |err| {
            switch (err) {
                error.EndOfStream => break,
                else => return err,
            }
        };

        // we know that each page number is two digit long, so it's safe to use a WindowIterator
        var it = std.mem.window(u8, line.items, 2, 3);
        while (it.next()) |tok| {
            if (tok.len == 0) continue :outer;
            const a = try std.fmt.parseInt(u8, tok, 10);
            // print("{d} ", .{a});
            for (pages.items) |b| {
                // if a violation is found, continue processing the next line
                if (violations.contains(.{ .left = b, .right = a })) {
                    // print("\n", .{});
                    // print("violated: {d}|{d}\n", .{ a, b });
                    continue :outer;
                }
            }
            try pages.append(a);
        }
        // print("\n", .{});

        assert(pages.items.len > 0);
        const middle = pages.items[pages.items.len / 2];
        sum += middle;
    }
    return sum;
}

test "part 1" {
    var fbs = std.io.fixedBufferStream(example);
    const answer = try solve1(testing.allocator, fbs.reader());
    try expectEqual(143, answer);
}

test "part 2" {
    return error.SkipZigTest;
}
