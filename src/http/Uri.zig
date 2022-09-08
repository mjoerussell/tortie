const std = @import("std");

pub fn PathParams(comptime path: []const u8) type {
    var iter = std.mem.split(u8, path, "/");
    var param_count = 0;
    while (iter.next()) |chunk| {
        if (getParamName(chunk)) |_| {
            param_count += 1;
        }
    }

    var fields: [param_count]std.builtin.TypeInfo.StructField = undefined;

    iter.index = 0;
    var param_index = 0;
    while (iter.next()) |chunk| {
        if (getParamName(chunk)) |param_name| {
            fields[param_index] = std.builtin.TypeInfo.StructField{
                .name = param_name,
                .field_type = []const u8,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf([]const u8),
            };
            param_index += 1;
        }
    }

    var base_type = @typeInfo(struct {});
    base_type.Struct.fields = fields[0..];

    const GeneratedPayloadType = @Type(base_type);

    return struct {
        pub const UriPayload = GeneratedPayloadType;
        pub const uri_pattern = path;

        pub fn match(actual_path: []const u8) ?UriPayload {
            @setEvalBranchQuota(100_000);
            var actual_chunk_iter = std.mem.split(u8, actual_path, "/");
            comptime var match_chunk_iter = std.mem.split(u8, path, "/");

            var uri: UriPayload = undefined;
            inline while (comptime match_chunk_iter.next()) |match_chunk| {
                const actual_chunk = actual_chunk_iter.next() orelse return null;

                // If this chunk maps to a path param, then assign the param's value now.
                // Otherwise, just make sure that the chunks match
                if (comptime getParamName(match_chunk)) |param_name| {
                    @field(uri, param_name) = actual_chunk;
                } else {
                    // Only check up to the beginning of query parameters, if they're present
                    const chunk_end_index = std.mem.indexOf(u8, actual_chunk, "?") orelse actual_chunk.len;
                    if (!std.ascii.eqlIgnoreCase(actual_chunk[0..chunk_end_index], match_chunk)) {
                        return null;
                    }
                }
            }

            return if (actual_chunk_iter.next() == null) uri else null;
        }
    };
}

const url_allowed_chars = [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_', '.', '~', '!', '*', '\'', '(', ')', ';', ':', '@', '&', '=', '+', ',', '\\', '?', '%', '#', '[', ']' };

pub fn urlEncode(text: []const u8, out_buffer: []u8) usize {
    var out_index: usize = 0;
    for (text) |c| {
        if (std.mem.indexOfScalar(u8, url_allowed_chars, c) == null) {
            if (out_index < out_buffer.len - 3) {
                out_buffer[out_index] = '%';
                const hex_str = toHex(c);
                out_buffer[out_index + 1] = hex_str[0];
                out_buffer[out_index + 2] = hex_str[1];
            }
            out_index += 3;
        }
    }

    return out_index;
}

pub fn urlEncodeAlloc(allocator: Allocator, text: []const u8) ![]const u8 {
    const len = urlEncode(text, [0]u8{});
    var buffer = try allocator.alloc(u8, len);
    return urlEncode(text, buffer);
}

fn toHex(byte: u8) [2]u8 {
    const left: u8 = byte >> 4;
    const right: u8 = byte & 0x0F;

    var res = [2]u8{ left, right };
    for (res) |*c| {
        c.* = switch (c.*) {
            0 => '0',
            1 => '1',
            2 => '2',
            3 => '3',
            4 => '4',
            5 => '5',
            6 => '6',
            7 => '7',
            8 => '8',
            9 => '9',
            0xA => 'A',
            0xB => 'B',
            0xC => 'C',
            0xD => 'D',
            0xE => 'E',
            0xF => 'F',
        };
    }

    return res;
}

fn getParamName(value: []const u8) ?[]const u8 {
    if (value.len <= 2) return null;
    if (value[0] != '{' or value[value.len - 1] != '}') return null;
    return value[1 .. value.len - 1];
}

test "basic uri params" {
    const Path = PathParams("/test/{a_param}");

    const params = Path.match("/test/value");

    try std.testing.expectEqualStrings("value", params.?.a_param);
}

test "multiple uri params" {
    const Path = PathParams("/test/{param_1}/somethingelse/{param_2}/last");

    const params = Path.match("/test/value1/somethingelse/value2/last").?;

    try std.testing.expectEqualStrings("value1", params.param_1);
    try std.testing.expectEqualStrings("value2", params.param_2);
}

test "Path.match should return null when actual < path" {
    const Path = PathParams("/test/abc");
    const params = Path.match("/test");

    try std.testing.expect(params == null);
}

test "Path.match should return null when actual > path" {
    const Path = PathParams("/test/abc");
    const params = Path.match("/test/abc/more");
    try std.testing.expect(params == null);
}

test "Path.match should ignore query params" {
    const Path = PathParams("/test/abc");
    const params = Path.match("/test/abc?param=val");

    try std.testing.expect(params != null);
}
