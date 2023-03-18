// made with gpt-4 to convert kseq.h from C to Zig
// release1
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const io = std.io;
const os = std.os;

pub const KSEQ_INIT = struct {
    in_buf: [4096]u8,
    d: fs.File,
    buf: []u8,
    last_char: usize,
    buf_size: usize,

    pub fn init(d: fs.File) KSEQ_INIT {
        return .{
            .in_buf = undefined,
            .d = d,
            .buf = undefined,
            .last_char = 0,
            .buf_size = 0,
        };
    }

    inline fn kgetc(ks: *KSEQ_INIT) !u8 {
        if (ks.last_char == ks.buf_size) {
            ks.buf_size = try ks.d.read(ks.in_buf[0..]);
            if (ks.buf_size == 0) return error.EndOfFile;
            ks.buf = ks.in_buf[0..ks.buf_size];
            ks.last_char = 0;
        }
        const ret = ks.buf[ks.last_char];
        ks.last_char += 1;
        return ret;
    }

    pub fn kseq_read(ks: *KSEQ_INIT, seq: *std.ArrayList(u8)) !bool {
        var c: u8 = undefined;
        seq.items.len = 0;

        while (true) {
            c = kgetc(ks) catch return false;
            if (c != 62 and c != 64) break; // ASCII values for '>' and '@'
        }

        while (c != 10) { // ASCII value for '\n'
            try seq.append(c);
            c = kgetc(ks) catch return false;
        }

        return true;
    }
};
