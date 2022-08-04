const std = @import("std");
const Allocator = std.mem.Allocator;

const Headers = @import("Headers.zig");

const Request = @This();

pub const HttpVersion = enum {
    http_11,
    http_2,
    http_3,

    pub fn fromString(text: []const u8) !HttpVersion {
        const eqlIgnoreCase = std.ascii.eqlIgnoreCase;
        if (eqlIgnoreCase(text, "HTTP/1.1")) return .http_11;
        if (eqlIgnoreCase(text, "HTTP/2")) return .http_2;
        if (eqlIgnoreCase(text, "HTTP/3")) return .http_3;
        return error.UnknownVersion;
    }

    pub fn toString(http_version: HttpVersion) []const u8 {
        return switch (http_version) {
            .http_11 => "HTTP/1.1",
            .http_2 => "HTTP/2",
            .http_3 => "HTTP/3",
        };
    }
};

pub const HttpMethod = enum {
    get,
    post,
    put,
    delete,
    head,
    options,

    pub fn fromString(text: []const u8) !HttpMethod {
        const eqlIgnoreCase = std.ascii.eqlIgnoreCase;
        if (eqlIgnoreCase(text, "get")) return .get;
        if (eqlIgnoreCase(text, "post")) return .post;
        if (eqlIgnoreCase(text, "put")) return .put;
        if (eqlIgnoreCase(text, "delete")) return .delete;
        if (eqlIgnoreCase(text, "head")) return .head;
        if (eqlIgnoreCase(text, "options")) return .options;
        return error.UnknownMethod;
    }
};

method: HttpMethod,
version: HttpVersion,
uri: []const u8,

headers: Headers = null,

body: ?[]const u8 = null,

pub fn parse(allocator: Allocator, data: []const u8) !Request {
    const ParseState = enum {
        status,
        headers,
        body,
    };

    var request: Request = undefined;
    request.headers = try Headers.init(allocator);
    errdefer request.headers.deinit();

    var parse_state = ParseState.status;
    var line_iter = std.mem.split(u8, data, "\r\n");
    // var current_index: usize = 0;

    // Increase current_index by the length of the line plus 2 to consider \r\n
    // while (line_iter.next()) |line| : (current_index += line.len + 2) {
    while (line_iter.next()) |line| {
        switch (parse_state) {
            .status => {
                var parts = std.mem.split(u8, line, " ");
                const method = parts.next() orelse return error.NoMethod;
                request.method = try HttpMethod.fromString(method);

                const uri = parts.next() orelse return error.NoUri;
                request.uri = uri;

                const version = parts.next() orelse return error.NoVersion;
                request.version = try HttpVersion.fromString(version);

                parse_state = .headers;
            },
            .headers => {
                if (line.len == 0) {
                    // Transition from headers -> body is indicated by "\r\n\r\n"
                    parse_state = .body;
                    continue;
                }

                const key_value_sep = std.mem.indexOf(u8, line, ":") orelse return error.InvalidHeader;
                const key = std.mem.trim(u8, line[0..key_value_sep], " ");

                var value_iter = std.mem.split(u8, line[key_value_sep + 1 ..], ",");
                while (value_iter.next()) |value| {
                    try request.headers.setHeader(key, std.mem.trim(u8, value, " "));
                }
            },
            .body => {
                // index has to have been initialized because the iterator has been called at least once.
                const body_index = line_iter.index orelse unreachable;
                request.body = data[body_index..];
                // Exit out, there's nothing left to do
                break;
            },
        }
    }

    return request;
}

pub fn queryParam(request: Request, param_name: []const u8) ?[]const u8 {
    const query_param_start = std.mem.indexOf(u8, request.uri, "?") orelse return null;
    if (query_param_start >= request.uri.len - 1) return null;

    const query_param_string = request.uri[query_param_start + 1 ..];
    var query_params = std.mem.split(u8, query_param_string, "&");
    while (query_params.next()) |param| {
        const index_of_eq = std.mem.indexOf(u8, param, "=") orelse return null;
        const current_param_name = param[0..index_of_eq];
        const current_param_value = param[index_of_eq + 1 ..];
        if (std.mem.eql(u8, current_param_name, param_name)) {
            return current_param_value;
        }
    }
    return null;
}

pub fn uriMatches(request: Request, test_uri: []const u8) bool {
    const parts = std.mem.split(u8, request.uri, "?");
    // Even if there's no '?' in the uri, it has to at least produce `req_uri` again
    // on the first call to next()
    const path = parts.next() orelse unreachable;
    return std.mem.eql(u8, path, test_uri);
}
