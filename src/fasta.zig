// demonstration of kseq.zig library to parse FASTA/FASTQ
// release2
// compilation tested with zig-macos-aarch64-0.11.0-dev.2227+f9b582950
// zig build-exe fasta.zig

const std = @import("std");
const kseq = @import("kseq.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: {s} <input_file>", .{args[0]});
        return;
    }

    const input_file_path = args[1];
    const file = try std.fs.cwd().openFile(input_file_path, .{});
    defer file.close();

    const seq = try kseq.kseq_init(allocator, file);
    defer kseq.kseq_destroy(allocator, seq);

    var num_sequences: usize = 0;
    var num_bases: usize = 0;

    while (true) {
        const read_result = kseq.kseq_read(std.heap.page_allocator, seq, file);
        if (read_result) |_| {
            num_sequences += 1;
            num_bases += seq.seq.l;
        } else |_| {
            std.log.err("Error reading sequence", .{});
            break;
        }
    }
    std.log.info("Number of sequences: {d}", .{num_sequences});
    std.log.info("Number of bases: {d}", .{num_bases});
}
