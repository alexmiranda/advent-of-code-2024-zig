const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    defer bw.flush() catch {}; // don't forget to flush!

    const stdout = bw.writer();
    try stdout.print("All your {s} are belong to us.\n", .{"codebase"});
}

test "part 1" {
    return error.SkipZigTest;
}

test "part 2" {
    return error.SkipZigTest;
}
