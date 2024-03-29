const std = @import("std");

const io = std.io;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

fn testBfMethod(comptime method: anytype, comptime program: []const u8, result: []const u8) !void {
    var in = [_]u8{0} ** 1024;
    var out = [_]u8{0} ** 1024;
    var tape = [_]u8{0} ** 1024;

    var reader = io.fixedBufferStream(&in);
    var writer = io.fixedBufferStream(&out);
    try method(program, &tape, reader.reader(), writer.writer());
    try testing.expect(mem.startsWith(u8, &out, result));
}

fn load(m: []const u8, ptr: usize) !u8 {
    if (m.len <= ptr)
        return error.OutOfBounds;

    return m[ptr];
}

fn store(m: []u8, ptr: usize, v: u8) !void {
    if (m.len <= ptr)
        return error.OutOfBounds;

    m[ptr] = v;
}

fn add(m: []u8, ptr: usize, v: u8) !void {
    var res: u8 = try load(m, ptr);
    store(m, ptr, res +% v) catch unreachable;
}

fn sub(m: []u8, ptr: usize, v: u8) !void {
    var res: u8 = try load(m, ptr);
    store(m, ptr, res -% v) catch unreachable;
}

pub fn interpret(program: []const u8, tape: []u8, reader: anytype, writer: anytype) !void {
    var ip: usize = 0;
    var mp: usize = 0;

    while (ip < program.len) : (ip += 1) {
        switch (try load(program, ip)) {
            '>' => mp = math.add(usize, mp, 1) catch return error.OutOfBounds,
            '<' => mp = math.sub(usize, mp, 1) catch return error.OutOfBounds,
            '+' => try add(tape, mp, 1),
            '-' => try sub(tape, mp, 1),
            '.' => try writer.writeByte(try load(tape, mp)),
            ',' => try store(tape, mp, try reader.readByte()),
            '[' => {
                if ((try load(tape, mp)) == 0) {
                    var skips: usize = 1;
                    while (skips != 0) {
                        ip = math.add(usize, ip, 1) catch return error.OutOfBounds;
                        switch (try load(program, ip)) {
                            '[' => skips += 1,
                            ']' => skips -= 1,
                            else => {},
                        }
                    }
                }
            },
            ']' => {
                if ((try load(tape, mp)) != 0) {
                    var skips: usize = 1;
                    while (skips != 0) {
                        ip = math.sub(usize, ip, 1) catch return error.OutOfBounds;
                        switch (try load(program, ip)) {
                            '[' => skips -= 1,
                            ']' => skips += 1,
                            else => {},
                        }
                    }
                }
            },
            else => {},
        }
    }
}

test "bf.interpret" {
    try testBfMethod(
        interpret,
        "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.",
        "Hello World!\n",
    );
}

pub fn compile(comptime program: []const u8, tape: []u8, reader: anytype, writer: anytype) !void {
    var mp: usize = 0;
    return try compileHelper(program, &mp, tape, reader, writer);
}

fn compileHelper(comptime program: []const u8, mp: *usize, tape: []u8, reader: anytype, writer: anytype) !void {
    comptime var ip = 0;
    inline while (ip < program.len) : (ip += 1) {
        switch (program[ip]) {
            '>' => mp.* = math.add(usize, mp.*, 1) catch return error.OutOfBounds,
            '<' => mp.* = math.sub(usize, mp.*, 1) catch return error.OutOfBounds,
            '+' => try add(tape, mp.*, 1),
            '-' => try sub(tape, mp.*, 1),
            '.' => try writer.writeByte(try load(tape, mp.*)),
            ',' => try store(tape, mp.*, try reader.readByte()),
            '[' => {
                const start = ip + 1;
                const end = comptime blk: {
                    var skips: usize = 1;
                    while (skips != 0) {
                        ip += 1;
                        switch (program[ip]) {
                            '[' => skips += 1,
                            ']' => skips -= 1,
                            else => {},
                        }
                    }

                    break :blk ip;
                };

                while ((try load(tape, mp.*)) != 0) {
                    try compileHelper(program[start..end], mp, tape, reader, writer);
                }
            },
            ']' => comptime unreachable,
            else => {},
        }
    }
}

test "bf.compile" {
    try testBfMethod(
        compile,
        "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.",
        "Hello World!\n",
    );
}
