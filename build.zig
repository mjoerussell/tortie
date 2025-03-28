const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    _ = b.addModule("tortie", .{
        .root_source_file = .{ .cwd_relative = "src/tortie.zig" },
    });
}
