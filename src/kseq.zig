// made with gpt-4 to convert kseq.h (https://github.com/lh3/seqtk/blob/f6ea81cc30b9232e244dffa94187114275389132/kseq.h) from C to Zig
// release2
// compilation tested with zig-macos-aarch64-0.11.0-dev.2227+f9b582950
// zig build-exe fasta.zig

const std = @import("std");
const Allocator = std.mem.Allocator;

// constants

pub const buf_size = 256;
const KS_SEP_SPACE = 0;
const KS_SEP_TAB = 1;
const KS_SEP_LINE = 2;
const KS_SEP_MAX = 2;

// data structures

pub const kstream_t = struct {
    buf: []u8,
    begin: i32,
    end: i32,
    is_eof: i32,
    fd: std.fs.File,
    left: usize,
    ptr: usize,
};

pub const kstring_t = struct {
    l: usize,
    m: usize,
    s: []u8,
};

pub const kseq_t = struct {
    name: kstring_t,
    comment: kstring_t,
    seq: kstring_t,
    qual: kstring_t,
    last_char: i32,
    is_fastq: bool,
    f: *kstream_t,
};

// functions

pub fn ks_init(allocator: std.mem.Allocator, fd: std.fs.File) !*kstream_t {
    const ks = try allocator.create(kstream_t);
    ks.buf = try allocator.alloc(u8, buf_size);
    ks.begin = 0;
    ks.end = 0;
    ks.is_eof = 0;
    ks.fd = fd;
    ks.left = 0;
    ks.ptr = 0;
    return ks;
}

pub fn ks_destroy(allocator: std.mem.Allocator, ks: ?*kstream_t) void {
    if (ks != null) {
        allocator.free(ks.?.buf);
        allocator.destroy(ks.?);
    }
}

pub fn kseq_init(allocator: std.mem.Allocator, fd: std.fs.File) !*kseq_t {
    const s = try allocator.create(kseq_t);
    s.f = try ks_init(allocator, fd);
    s.name = .{ .l = 0, .m = 0, .s = &[_]u8{} };
    s.comment = .{ .l = 0, .m = 0, .s = &[_]u8{} };
    s.seq = .{ .l = 0, .m = 0, .s = &[_]u8{} };
    s.qual = .{ .l = 0, .m = 0, .s = &[_]u8{} };
    s.last_char = 0;
    s.is_fastq = false;
    return s;
}

pub fn kseq_destroy(allocator: std.mem.Allocator, ks: ?*kseq_t) void {
    if (ks != null) {
        allocator.free(ks.?.name.s);
        allocator.free(ks.?.comment.s);
        allocator.free(ks.?.seq.s);
        allocator.free(ks.?.qual.s);
        ks_destroy(allocator, ks.?.f);
        allocator.destroy(ks.?);
    }
}

pub fn ks_err(ks: *kstream_t) bool {
    return ks.end < 0;
}

pub fn ks_eof(ks: *kstream_t) bool {
    return ks.is_eof != 0 and ks.begin >= ks.end;
}

pub fn ks_rewind(ks: *kstream_t) void {
    ks.is_eof = 0;
    ks.begin = 0;
    ks.end = 0;
}

fn fileRead(file: *const std.fs.File, buffer: [*]u8, size: usize) isize {
    const read_result = file.read(buffer[0..size]);
    if (read_result) |bytes_read| {
        return @intCast(isize, bytes_read);
    } else |_| {
        return -1;
    }
}

pub fn fileReadWrapper(file: *const std.fs.File, buffer: *u8, size: usize) isize {
    return fileRead(file, @ptrCast([*]u8, buffer), size);
}

pub fn ks_getc_wrapper(ks: *kstream_t, file: *const std.fs.File) isize {
    return ks_getc(ks, fileReadWrapper, file);
}

pub fn ks_getc(ks: *kstream_t, comptime readFn: fn (*const std.fs.File, *u8, usize) isize, file: *const std.fs.File) isize {
    if (ks.left == 0) {
        ks.left = @intCast(usize, readFn(file, &ks.buf[0], buf_size));
        if (ks.left <= 0) {
            return @intCast(isize, ks.left);
        }
        ks.ptr = 0;
    }

    const c = ks.buf[ks.ptr];
    ks.ptr += 1;
    ks.left -= 1;
    return c;
}

pub fn ks_getuntil2(allocator: std.mem.Allocator, ks: *kstream_t, delimiter: i32, str: *kstring_t, dret: ?*i32, append: bool, comptime readFn: fn (*const std.fs.File, *u8, usize) isize, file: *const std.fs.File) !isize {
    var gotany = false;
    if (dret) |value| value.* = 0;
    str.l = if (append) str.l else 0;

    while (true) {
        var i: isize = 0;
        if (ks_err(ks)) return -3;
        if (ks.begin >= ks.end) {
            if (ks.is_eof == 0) {
                ks.begin = 0;
                ks.end = @intCast(i32, readFn(file, &ks.buf[0], buf_size));
                if (ks.end == 0) {
                    ks.is_eof = 1;
                    break;
                }
                if (ks.end == -1) {
                    ks.is_eof = 1;
                    return -3;
                }
            } else break;
        }

        var found_delim = false;
        i = ks.begin;
        while (i < ks.end) {
            if (delimiter == KS_SEP_LINE) {
                if (ks.buf[@intCast(usize, i)] == '\n') {
                    found_delim = true;
                    break;
                }
            } else if (delimiter > KS_SEP_MAX) {
                if (ks.buf[@intCast(usize, i)] == @intCast(u8, delimiter)) {
                    found_delim = true;
                    break;
                }
            } else {
                const is_space = @import("std").ascii.isWhitespace(ks.buf[@intCast(usize, i)]);
                if ((delimiter == KS_SEP_SPACE and is_space) or
                    (delimiter == KS_SEP_TAB and is_space and ks.buf[@intCast(usize, i)] != ' '))
                {
                    found_delim = true;
                    break;
                }
            }
            i += 1;
        }

        if (!found_delim) {
            i = ks.end;
        }

        if (str.m - str.l < @intCast(usize, i) - @intCast(usize, ks.begin) + 1) {
            str.m = str.l + (@intCast(usize, i) - @intCast(usize, ks.begin)) + 1;
            var new_m_i32: i32 = @intCast(i32, str.m);
            kroundup32(&new_m_i32);
            str.m = @intCast(usize, new_m_i32);
            str.s = try allocator.realloc(str.s, str.m);
        }
        gotany = true;
        @memcpy(@ptrCast([*]u8, str.s) + str.l, @ptrCast([*]u8, ks.buf) + @intCast(usize, ks.begin), @intCast(usize, i - ks.begin));
        str.l += @intCast(usize, i) - @intCast(usize, ks.begin);
        ks.begin = @intCast(i32, i) + 1;
        if (found_delim) {
            if (dret) |value| value.* = ks.buf[@intCast(usize, i)];
            break;
        }
    }
    if (!gotany) return -1;
    str.s[str.l] = 0;
    return @intCast(isize, str.l);
}

pub fn kseq_read(allocator: std.mem.Allocator, seq: *kseq_t, file: std.fs.File) !i32 {
    var c: i32 = 0;
    var r: i32 = 0;
    const ks = seq.f;

    if (seq.last_char == 0) {
        while (true) {
            c = @intCast(i32, ks_getc_wrapper(ks, &file));
            if (c < 0 or c == '>' or c == '@') break;
        }

        seq.comment.l = 0;
        seq.seq.l = 0;
        seq.qual.l = 0;

        r = @intCast(i32, try ks_getuntil(allocator, ks, 0, &seq.name, &c, file));
        if (r < 0) return r;

        if (c != '\n') _ = try ks_getuntil(allocator, ks, KS_SEP_LINE, &seq.comment, null, file);

        if (seq.seq.s.len == 0) {
            seq.seq.m = 256;
            seq.seq.s = try allocator.alloc(u8, seq.seq.m);
        }

        while (c >= 0 and c != '>' and c != '+' and c != '@') {
            if (c == '\n') continue;
            seq.seq.s[seq.seq.l] = @intCast(u8, c);
            _ = try ks_getuntil2(allocator, ks, KS_SEP_LINE, &seq.seq, null, true, fileReadWrapper, &file);
            c = @intCast(i32, ks_getc_wrapper(ks, &file));
        }

        if (c == '>' or c == '@') seq.last_char = c;

        if (seq.seq.l + 1 >= seq.seq.m) {
            seq.seq.m = seq.seq.l + 2;
            var temp_m_i32: i32 = @intCast(i32, seq.seq.m);
            kroundup32(&temp_m_i32);
            seq.seq.m = @intCast(usize, temp_m_i32);
            seq.seq.s = try allocator.realloc(seq.seq.s, seq.seq.m);
        }

        seq.seq.s[seq.seq.l] = 0;
        seq.is_fastq = (c == '+');
        if (!seq.is_fastq) return @intCast(i32, seq.seq.l);

        if (seq.qual.m < seq.seq.m) {
            seq.qual.m = seq.seq.m;
            seq.qual.s = try allocator.realloc(seq.qual.s, seq.qual.m);
        }

        while (c >= 0 and c != '\n') {
            c = @intCast(i32, ks_getc_wrapper(ks, &file));
        }
        if (c == -1) return -2;

        while (c >= 0 and seq.qual.l < seq.seq.l) {
            c = @intCast(i32, try ks_getuntil2(allocator, ks, KS_SEP_LINE, &seq.qual, null, true, fileReadWrapper, &file));
        }

        if (c == -3) return -3;
        seq.last_char = 0;

        if (seq.seq.l != seq.qual.l) return -2;

        return @intCast(i32, seq.seq.l);
    }
    return -1;
}

fn ks_getuntil(allocator: std.mem.Allocator, ks: *kstream_t, delimiter: i32, strbuf: *kstring_t, delimiter_ret: ?*i32, file: std.fs.File) !isize {
    var c: i32 = 0;
    var l: isize = 0;

    if (strbuf.l + 256 >= strbuf.m) {
        var new_m_i32: i32 = @intCast(i32, strbuf.l + 256);
        kroundup32(&new_m_i32);
        strbuf.s = try allocator.realloc(strbuf.s, @intCast(usize, new_m_i32));
        strbuf.m = @intCast(usize, new_m_i32);
    }

    while (true) {
        c = @intCast(i32, ks_getc_wrapper(ks, &file));
        if (!(c != delimiter and c >= 0)) break;
        strbuf.s[@intCast(usize, l)] = @intCast(u8, c);
        l += 1;
        if (@intCast(usize, l) + 1 >= strbuf.m) {
            var new_m_i32: i32 = @intCast(i32, strbuf.l + 256);
            kroundup32(&new_m_i32);
            strbuf.m = @intCast(usize, new_m_i32);
            strbuf.s = try Allocator.realloc(allocator, strbuf.s, strbuf.m);
        }
    }

    strbuf.s[@intCast(usize, l)] = 0;
    strbuf.l = @intCast(usize, l);

    if (delimiter_ret) |ptr| {
        ptr.* = c;
    }

    if (c < 0) return c;
    return l;
}

fn kroundup32(x: *i32) void {
    x.* -= 1;
    x.* |= x.* >> 1;
    x.* |= x.* >> 2;
    x.* |= x.* >> 4;
    x.* |= x.* >> 8;
    x.* |= x.* >> 16;
    x.* += 1;
}
