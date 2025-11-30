const std = @import("std");
const print = std.debug.print;
const panic = std.debug.panic;
const testing = std.testing;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const pow = std.math.pow;
const divExact = std.math.divExact;
const example = @embedFile("example.txt");

const Operator = enum(u8) {
    add = 1,
    mul = 2,
    concat = 4,
};

const Operators = std.EnumSet(Operator);

const Calibration = struct {
    ally: Allocator,
    equations: []Equation,

    fn initParse(ally: Allocator, reader: *std.Io.Reader) !Calibration {
        var array: std.ArrayList(Equation) = try .initCapacity(ally, 10);
        defer array.deinit(ally);

        while (reader.takeDelimiterExclusive('\n')) |line| {
            reader.toss(1); // skip the newline
            if (line.len == 0) continue;
            const eq = try Equation.initParse(ally, line);
            try array.append(ally, eq);
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }
        return .{ .ally = ally, .equations = try array.toOwnedSlice(ally) };
    }

    fn deinit(self: Calibration) void {
        for (self.equations) |*eq| eq.deinit();
        self.ally.free(self.equations);
    }

    fn totalCalibrationResult(self: Calibration, ops: Operators) !u64 {
        var sum: u64 = 0;
        for (self.equations) |*eq| {
            sum += try eq.repair(ops);
        }
        return sum;
    }
};

const Equation = struct {
    ally: Allocator,
    testValue: u64,
    numbers: []u64,

    fn initParse(ally: Allocator, buffer: []const u8) !Equation {
        var array: std.ArrayList(u64) = try .initCapacity(ally, 10);
        defer array.deinit(ally);

        const colon_idx = std.mem.indexOfScalarPos(u8, buffer, 1, ':').?;
        const testValue = try std.fmt.parseInt(u64, buffer[0..colon_idx], 10);
        var it = std.mem.splitScalar(u8, buffer[colon_idx + 2 ..], ' ');
        while (it.next()) |tok| {
            const number = try std.fmt.parseInt(u64, tok, 10);
            try array.append(ally, number);
        }

        const numbers = try array.toOwnedSlice(ally);
        return .{ .ally = ally, .testValue = testValue, .numbers = numbers };
    }

    fn deinit(self: *Equation) void {
        self.ally.free(self.numbers);
    }

    fn repair(self: *Equation, ops: Operators) !u64 {
        const ally = self.ally;
        const State = struct { testValue: u64, slide: usize };
        var stack: std.ArrayList(State) = try .initCapacity(ally, pow(usize, ops.count(), self.numbers.len));
        defer stack.deinit(self.ally);

        // print("repairing equation: {d}: {any}\n", .{ self.testValue, self.numbers });

        stack.appendAssumeCapacity(.{ .testValue = self.testValue, .slide = self.numbers.len - 1 });
        return while (stack.items.len > 0) {
            // take the last item from the stack
            const state = stack.swapRemove(stack.items.len - 1);
            const n = self.numbers[state.slide];
            // print("state: {any} n: {d}\n", .{ state, n });

            // if the equation can be solved by comparing n to the testValue in the last step,
            // we return the testValue of the whole equation
            if (state.slide == 0) {
                if (n == state.testValue) break self.testValue;
                continue;
            }

            // if the testValue is divisible by n, we can attempt multiplication
            if (ops.contains(.mul) and state.testValue % n == 0 and n > 0) {
                const testValue = try divExact(u64, state.testValue, n);
                stack.appendAssumeCapacity(.{ .testValue = testValue, .slide = state.slide - 1 });
            }

            // if the testValue is still greater than or equal n, we can attempt addition
            if (ops.contains(.add) and state.testValue >= n) {
                const testValue = state.testValue - n;
                stack.appendAssumeCapacity(.{ .testValue = testValue, .slide = state.slide - 1 });
            }

            // if the testValue ends with n, we can attempt concatenation
            const log10n = std.math.log10_int(n);
            // print("test: {d}\n", .{state.testValue % pow(u64, 10, (log10n + 1))});
            if (ops.contains(.concat) and state.testValue % pow(u64, 10, log10n + 1) == n) {
                const testValue = (state.testValue - n) / pow(u64, 10, log10n + 1);
                stack.appendAssumeCapacity(.{ .testValue = testValue, .slide = state.slide - 1 });
            }
        } else 0; // couldn't solve the equation
    }
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout = &stdout_writer.interface;

    var input_file = std.fs.cwd().openFile("day07/input.txt", .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => @panic("Input file is missing"),
            else => panic("{any}", .{err}),
        }
    };
    defer input_file.close();

    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .init;
    defer if (gpa.deinit() == .leak) @panic("Memory leak");
    const ally = gpa.allocator();

    var read_buffer: [1024]u8 = undefined;
    var reader = std.fs.File.reader(input_file, &read_buffer);
    const calibration = try Calibration.initParse(ally, &reader.interface);
    defer calibration.deinit();

    const ops_p1 = Operators.initMany(&[_]Operator{ .add, .mul });
    const answer_p1 = try calibration.totalCalibrationResult(ops_p1);
    try stdout.print("Part 1: {d}\n", .{answer_p1});

    const ops_p2 = Operators.initFull();
    const answer_p2 = try calibration.totalCalibrationResult(ops_p2);
    try stdout.print("Part 2: {d}\n", .{answer_p2});
    try stdout.flush();
}

test "part 1" {
    var reader: std.Io.Reader = .fixed(example);
    const calibration = try Calibration.initParse(testing.allocator, &reader);
    defer calibration.deinit();
    const ops = Operators.initMany(&[_]Operator{ .add, .mul });
    try expectEqual(3749, try calibration.totalCalibrationResult(ops));
}

test "part 2" {
    var reader: std.Io.Reader = .fixed(example);
    const calibration = try Calibration.initParse(testing.allocator, &reader);
    defer calibration.deinit();
    const ops = Operators.initFull();
    try expectEqual(11387, try calibration.totalCalibrationResult(ops));
}
