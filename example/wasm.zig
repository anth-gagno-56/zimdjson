/// zimdjson WASM module — generic JSON pretty-printer
///
/// Exports:
///   getInputPtr()  -> [*]u8   — write JSON bytes here before calling parse
///   getInputLen()  -> u32     — capacity of the input buffer
///   getOutputPtr() -> [*]u8   — read result text from here after parse
///   parse(len: u32) -> u32    — parse len bytes of input; returns result byte count (0 = error)
const std = @import("std");
const zimdjson = @import("zimdjson");

const Parser = zimdjson.ondemand.FullParser(.default);

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
/// Writes a human-readable pretty-printed representation to output_buf.
/// Returns the byte length written; on error writes an error message and still returns its length.
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

// ── generic pretty-printer ────────────────────────────────────────────────────

fn parseJson(allocator: std.mem.Allocator, json: []const u8) !u32 {
    var parser = Parser.init;
    defer parser.deinit(allocator);

    const document = try parser.parseFromSlice(allocator, json);

    var out = std.io.fixedBufferStream(&output_buf);
    const w = out.writer();

    try printValue(w, document.asValue(), 0);
    try w.writeByte('\n');

    return @intCast(out.pos);
}

fn printIndent(w: anytype, depth: usize) !void {
    var i: usize = 0;
    while (i < depth) : (i += 1) try w.writeAll("  ");
}

/// Recursively pretty-print a zimdjson ondemand Value.
fn printValue(w: anytype, value: Parser.Value, depth: usize) !void {
    const any = try value.asAny();
    switch (any) {
        .null => try w.writeAll("null"),
        .bool => |b| try w.writeAll(if (b) "true" else "false"),
        .number => |n| switch (n) {
            .unsigned => |u| try w.print("{d}", .{u}),
            .signed => |s| try w.print("{d}", .{s}),
            .double => |d| try w.print("{d}", .{d}),
        },
        .string => |raw| {
            const s = try raw.getTemporal();
            try w.writeByte('"');
            try writeEscaped(w, s);
            try w.writeByte('"');
        },
        .array => |arr| {
            try w.writeAll("[\n");
            var it = arr.iterator();
            var first = true;
            while (try it.next()) |el| {
                if (!first) try w.writeAll(",\n");
                first = false;
                try printIndent(w, depth + 1);
                try printValue(w, el, depth + 1);
            }
            if (!first) try w.writeByte('\n');
            try printIndent(w, depth);
            try w.writeByte(']');
        },
        .object => |obj| {
            try w.writeAll("{\n");
            var it = obj.iterator();
            var first = true;
            while (try it.next()) |field| {
                if (!first) try w.writeAll(",\n");
                first = false;
                try printIndent(w, depth + 1);
                const key = try field.key.getTemporal();
                try w.writeByte('"');
                try writeEscaped(w, key);
                try w.writeAll("\": ");
                try printValue(w, field.value, depth + 1);
            }
            if (!first) try w.writeByte('\n');
            try printIndent(w, depth);
            try w.writeByte('}');
        },
    }
}

/// Write a string with JSON escape sequences for special characters.
fn writeEscaped(w: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            else => try w.writeByte(c),
        }
    }
}
