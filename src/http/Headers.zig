const std = @import("std");
const Allocator = std.mem.Allocator;

const Headers = @This();

const StringRange = struct {
    start: u32,
    end: u32,
};

const HeaderMap = std.StringHashMap(std.ArrayListUnmanaged(StringRange));

const HeaderIterator = struct {
    const Entry = struct {
        key: []const u8,
        values: HeaderValueIterator,
    };

    headers: *Headers,
    key_index: usize = 0,

    pub fn next(iter: *HeaderIterator) ?Entry {
        while (iter.key_index < iter.headers.keys.items.len) {
            defer iter.key_index += 1;
            const current_key_range = iter.headers.keys.items[iter.key_index];
            const current_key = iter.headers.getDataFromRange(current_key_range);

            if (iter.headers.getHeader(current_key)) |value_iter| {
                return Entry{
                    .key = current_key,
                    .values = value_iter,
                };
            }
        }

        return null;
    }
};

const HeaderValueIterator = struct {
    index: usize = 0,
    value_ranges: []StringRange,
    data: []const u8,

    pub fn next(iter: *HeaderValueIterator) ?[]const u8 {
        if (iter.index >= iter.value_ranges.len) return null;

        const current_range = iter.value_ranges[iter.index];
        const value = iter.data[@intCast(usize, current_range.start)..@intCast(usize, current_range.end)];
        iter.index += 1;
        return value;
    }
};

data: std.ArrayListUnmanaged(u8),
temp_buffer: [1024]u8 = undefined,
keys: std.ArrayListUnmanaged(StringRange),
values: HeaderMap,
allocator: Allocator,

pub fn init(allocator: Allocator) !Headers {
    return Headers{
        .keys = try std.ArrayListUnmanaged(StringRange).initCapacity(allocator, 32),
        .data = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 4096),
        .values = HeaderMap.init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(headers: *Headers) void {
    var value_iter = headers.values.valueIterator();
    while (value_iter.next()) |value| value.deinit(headers.allocator);
    headers.values.deinit();
    headers.data.deinit(headers.allocator);
    headers.keys.deinit(headers.allocator);
    headers.allocator.free(headers.temp_buffer);
}

pub fn setHeader(headers: *Headers, header_name: []const u8, header_value: anytype) !void {
    const lower_name = headers.getLower(header_name);
    const data_range = try headers.addData(header_value);

    var entry = try headers.values.getOrPut(lower_name);
    if (!entry.found_existing) {
        const key_range = try headers.addData(lower_name);
        try headers.keys.append(headers.allocator, key_range);
        entry.value_ptr.* = try std.ArrayListUnmanaged(StringRange).initCapacity(headers.allocator, 8);
        entry.value_ptr.appendAssumeCapacity(data_range);
    } else {
        try entry.value_ptr.append(headers.allocator, data_range);
    }
}

pub fn getHeader(headers: *Headers, header_name: []const u8) ?HeaderValueIterator {
    const lower_name = headers.getLower(header_name);
    if (headers.values.get(lower_name)) |header_values| {
        return HeaderValueIterator{
            .value_ranges = header_values.items,
            .data = headers.data.items,
        };
    }

    return null;
}

pub fn getFirstValue(headers: *Headers, header_name: []const u8) ?[]const u8 {
    const lower_name = headers.getLower(header_name);
    const values = headers.values.get(lower_name) orelse return null;
    if (values.items.len < 1) return null;

    const range = values.items[0];
    return headers.data.items[@intCast(usize, range.start)..@intCast(usize, range.end)];
}

pub fn iterate(headers: *Headers) HeaderIterator {
    return HeaderIterator{
        .headers = headers,
    };
}

fn addData(headers: *Headers, value: anytype) !StringRange {
    const value_is_str = comptime std.meta.trait.isZigString(@TypeOf(value));
    const data_start_len = headers.data.items.len;

    const writer = headers.data.writer(headers.allocator);
    if (value_is_str) {
        try writer.writeAll(value);
    } else {
        try writer.print("{}", .{value});
    }

    const data_end_len = headers.data.items.len;
    return StringRange{
        .start = @intCast(u32, data_start_len),
        .end = @intCast(u32, data_end_len),
    };
}

fn getDataFromRange(headers: *const Headers, range: StringRange) []const u8 {
    return headers.data.items[@intCast(usize, range.start)..@intCast(usize, range.end)];
}

fn getLower(headers: *Headers, header_name: []const u8) []const u8 {
    // find the min between the length of the input vs. the length of the temp buffer
    const name_end_index = if (header_name.len < headers.temp_buffer.len) header_name.len else headers.temp_buffer.len;
    std.mem.copy(u8, &headers.temp_buffer, header_name[0..name_end_index]);

    var result = headers.temp_buffer[0..name_end_index];
    for (result) |*c| {
        c.* = std.ascii.toLower(c.*);
    }
    return result;
}
