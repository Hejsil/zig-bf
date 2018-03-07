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

    fn readFn(in_stream: &Stream, buffer: []u8) Error!usize {
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

    fn writeFn(out_stream: &Stream, buffer: []const u8) Error!void {
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
    interpret(program, tape[0..], &in_fs.stream, &out_fs.stream);
    debug.assert(mem.startsWith(u8, out, "Hello World!\n"));
}

pub fn interpret(program: []const u8, tape: []u8, in_stream: var, out_stream: var) void {
    var ip : usize = 0;
    var mp : usize = 0;

    while (ip < program.len) : (ip += 1) {
        switch (program[ip]) {
            '>' => mp += 1,
            '<' => mp -= 1,
            '+' => tape[mp] += 1,
            '-' => tape[mp] -= 1,
            '.' => out_stream.writeByte(tape[mp]) catch unreachable,
            ',' => tape[mp] = in_stream.readByte() catch unreachable,
            '[' => {
                if (tape[mp] == 0) {
                    while (program[ip] != ']')
                        ip += 1;
                }
            },
            ']' => {
                if (tape[mp] != 0) {
                    while (program[ip] != '[')
                        ip -= 1;
                }
            },
            else => unreachable,
        }
    }
}
