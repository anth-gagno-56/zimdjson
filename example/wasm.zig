/// zimdjson WASM module
/// Exports:
///   getInputPtr()  -> [*]u8   — write JSON bytes here before calling parse
///   getInputLen()  -> u32     — capacity of the input buffer
///   getOutputPtr() -> [*]u8   — read result text from here after parse
///   parse(len: u32) -> u32    — parse len bytes of input; returns result byte count (0 = error)
const std = @import("std");
const zimdjson = @import("zimdjson");

// ── memory layout ────────────────────────────────────────────────────────────
const INPUT_CAP = 2 * 1024 * 1024; //  2 MB  – JSON input
const OUTPUT_CAP = 2 * 1024 * 1024; //  2 MB  – text output
const HEAP_CAP = 8 * 1024 * 1024; //  8 MB  – parser scratch space

var input_buf: [INPUT_CAP]u8 = undefined;
var output_buf: [OUTPUT_CAP]u8 = undefined;
var heap_buf: [HEAP_CAP]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&heap_buf);

// ── exports ───────────────────────────────────────────────────────────────────
export fn getInputPtr() [*]u8 {
    return &input_buf;
}
export fn getInputLen() u32 {
    return INPUT_CAP;
}
export fn getOutputPtr() [*]u8 {
    return &output_buf;
}

/// Parse JSON in input_buf[0..len].
/// Writes UTF-8 plain text to output_buf and returns its byte length.
/// Returns 0 on any error (output_buf will then contain an error message).
export fn parse(len: u32) u32 {
    fba.reset();
    const allocator = fba.allocator();
    const json = input_buf[0..len];

    const n = parseJson(allocator, json) catch |err| {
        const label = @errorName(err);
        const msg = std.fmt.bufPrint(&output_buf, "Error: {s}", .{label}) catch "Error";
        return @intCast(msg.len);
    };
    return n;
}

// ── implementation ────────────────────────────────────────────────────────────

fn parseJson(allocator: std.mem.Allocator, json: []const u8) !u32 {
    var parser = zimdjson.ondemand.FullParser(.default).init;
    defer parser.deinit(allocator);

    const document = try parser.parseFromSlice(allocator, json);

    var out = std.io.fixedBufferStream(&output_buf);
    const w = out.writer();

    // ── search_metadata ───────────────────────────────────────────────────────
    const count = try document.at("search_metadata").at("count").asUnsigned();
    const completed = try document.at("search_metadata").at("completed_in").asDouble();

    try w.print("search_metadata\n", .{});
    try w.print("  count        : {d}\n", .{count});
    try w.print("  completed_in : {d:.4}s\n\n", .{completed});

    // ── statuses ──────────────────────────────────────────────────────────────
    try w.print("statuses\n", .{});

    var statuses = (try document.at("statuses").asArray()).iterator();
    var idx: usize = 0;
    while (try statuses.next()) |status| {
        idx += 1;
        const id = try status.at("id").asUnsigned();
        const text = try status.at("text").asString();
        const user_name = try status.at("user").at("name").asString();
        const screen_name = try status.at("user").at("screen_name").asString();
        const followers = try status.at("user").at("followers_count").asUnsigned();
        const retweets = try status.at("retweet_count").asUnsigned();

        try w.print("\n  [{d}] id            : {d}\n", .{ idx, id });
        try w.print("       text          : {s}\n", .{text});
        try w.print("       user          : {s} (@{s})\n", .{ user_name, screen_name });
        try w.print("       followers     : {d}\n", .{followers});
        try w.print("       retweet_count : {d}\n", .{retweets});
    }

    return @intCast(out.pos);
}
