// demonstration of kseq.zig library to parse FASTA/FASTQ
// release1 - not correct output right now
// compilation tested with Zig version 0.10.1 
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const io = std.io;
const os = std.os;

const KSEQ_INIT = @import("kseq.zig").KSEQ_INIT;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: {s} <input_file>", .{args[0]});
        return;
    }

    const file_path = args[1];
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    var kseq = KSEQ_INIT.init(file);
    var seq = std.ArrayList(u8).init(allocator);
    defer seq.deinit();

    var num_seqs: usize = 0;
    var num_bases: usize = 0;

    while (try kseq.kseq_read(&seq)) {
        num_seqs += 1;
        num_bases += seq.items.len;
    }

    std.log.info("Number of sequences: {d}", .{ num_seqs });
    std.log.info("Number of bases: {d}", .{ num_bases });
}
