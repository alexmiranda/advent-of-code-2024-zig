const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const example = @embedFile("example.txt");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day05/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    var reader_buffer: [1024]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &reader_buffer);
    const answer_p1 = try solve1(ally, &reader.interface);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    try reader.seekTo(0);
    const answer_p2 = try solve2(ally, &reader.interface);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

fn solve1(ally: std.mem.Allocator, reader: *std.Io.Reader) !u32 {
    const Rule = struct { left: u8, right: u8 };
    var violations: std.AutoHashMap(Rule, void) = .init(ally);
    defer violations.deinit();

    // first we read all the rules and create violation rules i.e. b > a
    while (true) {
        const read = try reader.takeDelimiterExclusive('\n');
        if (read.len == 0) {
            reader.toss(1); // skip blank line
            break;
        }
        const a = try std.fmt.parseInt(u8, read[0..2], 10);
        const b = try std.fmt.parseInt(u8, read[3..], 10);
        try violations.put(.{ .left = b, .right = a }, {});
        reader.toss(1); // skip the newline
    }

    var line_writer: std.Io.Writer.Allocating = try .initCapacity(ally, 100);
    defer line_writer.deinit();

    var pages: std.ArrayList(u8) = .empty;
    defer pages.deinit(ally);

    var sum: u32 = 0;
    outer: while (true) {
        defer _ = line_writer.writer.consumeAll();
        defer pages.clearRetainingCapacity();

        // read each line
        if (try reader.streamDelimiterLimit(&line_writer.writer, '\n', .limited(100)) == 0) break;
        reader.toss(1); // skip the newline

        // we know that each page number is two digit long, so it's safe to use a WindowIterator
        const line = line_writer.writer.buffered();
        var it = std.mem.window(u8, line, 2, 3);
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
            try pages.append(ally, a);
        }
        // print("\n", .{});

        assert(pages.items.len > 0);
        const middle = pages.items[pages.items.len / 2];
        sum += middle;
    }
    return sum;
}

fn solve2(ally: std.mem.Allocator, reader: *std.Io.Reader) !u32 {
    const Rule = struct { left: u8, right: u8 };

    // first we read all the rules and create a permitted: a < b; and violation rule: b < a
    const rules = blk: {
        var set: std.AutoHashMap(Rule, std.math.Order) = .init(ally);
        errdefer set.deinit();
        while (true) {
            const read = try reader.takeDelimiterExclusive('\n');
            if (read.len == 0) {
                reader.toss(1); // skip the blank line
                break;
            }
            const a = try std.fmt.parseInt(u8, read[0..2], 10);
            const b = try std.fmt.parseInt(u8, read[3..], 10);
            try set.put(.{ .left = a, .right = b }, .lt);
            try set.put(.{ .left = b, .right = a }, .gt);
            reader.toss(1); // skip the newline
        }
        break :blk &set;
    };
    defer rules.deinit();

    var line_writer: std.Io.Writer.Allocating = try .initCapacity(ally, 100);
    defer line_writer.deinit();

    var pages: std.ArrayList(u8) = .empty;
    defer pages.deinit(ally);

    var sum: u32 = 0;
    outer: while (true) {
        defer _ = line_writer.writer.consumeAll();
        defer pages.clearRetainingCapacity();

        // read each line
        if (try reader.streamDelimiterLimit(&line_writer.writer, '\n', .limited(100)) == 0) break;
        reader.toss(1); // skip the newline

        // check if it's an empty line
        const line = line_writer.writer.buffered();
        if (line.len == 0) continue :outer;

        // we know that each page number is two digit long, so it's safe to use a WindowIterator
        var incorrectly_ordered = false;
        var it = std.mem.window(u8, line, 2, 3);
        while (it.next()) |tok| {
            if (tok.len == 0) continue :outer;
            const a = try std.fmt.parseInt(u8, tok, 10);

            // because we need to count only the incorrectly ordered updates, we need to do this gimmickry
            if (!incorrectly_ordered) {
                for (pages.items) |b| {
                    // if a violation is found, we attempt to fix it
                    if (rules.get(.{ .left = b, .right = a })) |order| {
                        if (order == .gt) {
                            incorrectly_ordered = true;
                            break;
                        }
                    }
                }
            }
            try pages.append(ally, a);
        }

        assert(pages.items.len > 0);
        if (incorrectly_ordered) {
            const S = struct {
                pub fn lessThan(ctx: @TypeOf(rules), a: u8, b: u8) bool {
                    const cmp = ctx.get(.{ .left = a, .right = b }) orelse .eq;
                    return switch (cmp) {
                        .gt => false,
                        else => true,
                    };
                }
            };
            std.sort.heap(u8, pages.items, rules, S.lessThan);
            const middle = pages.items[pages.items.len / 2];
            sum += middle;
        }
    }
    return sum;
}
test "part 1" {
    var reader: std.Io.Reader = .fixed(example);
    const answer = try solve1(testing.allocator, &reader);
    try expectEqual(143, answer);
}

test "part 2" {
    var reader: std.Io.Reader = .fixed(example);
    const answer = try solve2(testing.allocator, &reader);
    try expectEqual(123, answer);
}
