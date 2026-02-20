const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // build_options required by src/indexer.zig and src/tracy.zig
    const build_options = b.addOptions();
    build_options.addOption(bool, "is_dev_mode", false);
    build_options.addOption(bool, "enable_tracy", false);

    // Import zimdjson from parent directory
    const zimdjson = b.addModule("zimdjson", .{
        .root_source_file = b.path("../src/zimdjson.zig"),
    });
    zimdjson.addImport("build_options", build_options.createModule());

    // Create the example executable
    const exe = b.addExecutable(.{
        .name = "zimdjson-example",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zimdjson", zimdjson);
    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the zimdjson example");
    run_step.dependOn(&run_cmd.step);

    // ── WASM build ────────────────────────────────────────────────────────────
    // Target: wasm32-freestanding with SIMD128 (required by zimdjson's SIMD indexer)
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.wasm.featureSet(&.{.simd128}),
    });

    // build_options for the WASM zimdjson module
    const wasm_build_options = b.addOptions();
    wasm_build_options.addOption(bool, "is_dev_mode", false);
    wasm_build_options.addOption(bool, "enable_tracy", false);

    const zimdjson_wasm = b.addModule("zimdjson", .{
        .root_source_file = b.path("../src/zimdjson.zig"),
    });
    zimdjson_wasm.addImport("build_options", wasm_build_options.createModule());

    const wasm_exe = b.addExecutable(.{
        .name = "zimdjson",
        .root_source_file = b.path("wasm.zig"),
        .target = wasm_target,
        .optimize = .ReleaseSmall,
    });
    wasm_exe.entry = .disabled; // no main – only exported functions
    wasm_exe.rdynamic = true; // keep export symbols
    wasm_exe.root_module.addImport("zimdjson", zimdjson_wasm);

    // Copy the .wasm file into ../html/
    const install_wasm = b.addInstallFile(wasm_exe.getEmittedBin(), "../../html/zimdjson.wasm");

    const wasm_step = b.step("wasm", "Build the WASM module and install to html/");
    wasm_step.dependOn(&install_wasm.step);
}
