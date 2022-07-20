const std = @import("std");
const Allocator = std.mem.Allocator;

const http = @import("http");
const FileSource = @import("FileSource.zig");

const Route = @This();

pub const Handler = fn (Allocator, ?FileSource, http.Request) callconv(.Async) anyerror!http.Response;

uri: []const u8,
handler: Handler,

pub fn matches(route: Route, path: []const u8) bool {
    const query_params_start = std.mem.indexOf(u8, path, "?") orelse path.len;
    return std.mem.eql(u8, route.uri, path[0..query_params_start]);
}