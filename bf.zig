const std = @import("std");

const io    = std.io;
const mem   = std.mem;
const math  = std.math;
const debug = std.debug;

pub const MemInStream = struct {
    memory: []u8,
    stream: Stream,

    pub const Error = error{};
    pub const Stream = io.InStream(Error);

    pub fn init(memory: []u8) MemInStream {
        return MemInStream {
            .memory = memory,
            .stream = Stream {
                .readFn = readFn
            }
        };
    }

    fn readFn(in_stream: *Stream, buffer: []u8) Error!usize {
        const self = @fieldParentPtr(MemInStream, "stream", in_stream);
        const bytes_read = math.min(buffer.len, self.memory.len);

        mem.copy(u8, buffer, self.memory[0..bytes_read]);
        self.memory = self.memory[bytes_read..];

        return bytes_read;
    }
};

pub const MemOutStream = struct {
    memory: []u8,
    stream: Stream,

    pub const Error = error{};
    pub const Stream = io.OutStream(Error);

    pub fn init(memory: []u8) MemOutStream {
        return MemOutStream {
            .memory = memory,
            .stream = Stream {
                .writeFn = writeFn
            }
        };
    }

    fn writeFn(out_stream: *Stream, buffer: []const u8) Error!void {
        const self = @fieldParentPtr(MemOutStream, "stream", out_stream);
        const bytes_written = math.min(buffer.len, self.memory.len);

        mem.copy(u8, self.memory[0..bytes_written], buffer);
        self.memory = self.memory[bytes_written..];
    }
};

test "bf.interpret: Hello World" {
    var in = []u8{0} ** 1024;
    var out = []u8{0} ** 1024;
    var tape = []u8{0} ** 1024;

    var in_fs = MemInStream.init(in[0..]);
    var out_fs = MemOutStream.init(out[0..]);
    const program = "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.";
    try interpret(program, tape[0..], &in_fs.stream, &out_fs.stream);
    debug.assert(mem.startsWith(u8, out, "Hello World!\n"));
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

pub fn interpret(program: []const u8, tape: []u8, in_stream: var, out_stream: var) !void {
    var ip : usize = 0;
    var mp : usize = 0;

    while (ip < program.len) : (ip += 1) {
        switch (try load(program, ip)) {
            '>' => mp = math.add(usize, mp, 1) catch return error.OutOfBounds,
            '<' => mp = math.sub(usize, mp, 1) catch return error.OutOfBounds,
            '+' => try add(tape, mp, 1),
            '-' => try sub(tape, mp, 1),
            '.' => try out_stream.writeByte(try load(tape, mp)),
            ',' => try store(tape, mp, try in_stream.readByte()),
            '[' => {
                if (tape[mp] == 0) {
                    var skips: usize = 1;
                    while (skips != 0) {
                        ip = math.add(usize, ip, 1) catch return error.OutOfBounds;
                        switch (try load(program, ip)) {
                            '[' => skips += 1,
                            ']' => skips -= 1,
                            else => {}
                        }
                    }
                }
            },
            ']' => {
                if (tape[mp] != 0) {
                    var skips: usize = 1;
                    while (skips != 0) {
                        ip = math.sub(usize, ip, 1) catch return error.OutOfBounds;
                        switch (try load(program, ip)) {
                            '[' => skips -= 1,
                            ']' => skips += 1,
                            else => {}
                        }
                    }
                }
            },
            else => {},
        }
    }
}
