const std = @import("std");
const io = std.io;

pub fn main() !void {
    var std_in_file = try io.getStdIn();
    var std_out_file = try io.getStdOut();
    var std_in_fs = io.FileInStream.init(&std_in_file);
    var std_out_fs = io.FileOutStream.init(&std_out_file);
    var tape = []u8{0} ** 1024;

    const program = "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.";
    interpret(program, tape[0..], &std_in_fs.stream, &std_out_fs.stream);
}

fn interpret(program: []const u8, tape: []u8, in_stream: var, out_stream: var) void {
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
