const std = @import("std");
const Allocator = std.mem.Allocator;

const Headers = @This();

const StringRange = struct {
    start: u32,
    end: u32,

    fn size(range: StringRange) u32 {
        return range.end - range.start;
    }
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

            var header_iter = iter.headers.getHeader(current_key) catch continue;
            if (header_iter) |value_iter| {
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
keys: std.ArrayListUnmanaged(StringRange),
values: HeaderMap,
allocator: Allocator,

pub fn init(allocator: Allocator) !Headers {
    return Headers{
        .keys = try std.ArrayListUnmanaged(StringRange).initCapacity(allocator, 32),
        .data = try std.ArrayListUnmanaged(u8).initCapacity(allocator, 1024),
        .values = HeaderMap.init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(headers: *Headers) void {
    var value_iter = headers.values.iterator();
    while (value_iter.next()) |entry| {
        headers.allocator.free(entry.key_ptr.*);
        entry.value_ptr.deinit(headers.allocator);
    }
    headers.values.deinit();
    headers.data.deinit(headers.allocator);
    headers.keys.deinit(headers.allocator);
}

pub fn setHeader(headers: *Headers, header_name: []const u8, header_value: anytype) !void {
    const lower_name = try getLower(headers.allocator, header_name);
    errdefer headers.allocator.free(lower_name);

    const data_range = try headers.addData(header_value);
    errdefer headers.data.items.len -= data_range.size();

    var entry = try headers.values.getOrPut(lower_name);
    if (!entry.found_existing) {
        const key_range = try headers.addData(lower_name);
        errdefer headers.data.items.len -= key_range.size();

        try headers.keys.append(headers.allocator, key_range);
        entry.value_ptr.* = try std.ArrayListUnmanaged(StringRange).initCapacity(headers.allocator, 8);
        entry.value_ptr.appendAssumeCapacity(data_range);
    } else {
        try entry.value_ptr.append(headers.allocator, data_range);
    }
}

pub fn getHeader(headers: *Headers, header_name: []const u8) !?HeaderValueIterator {
    var temp_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&temp_buffer);

    const lower_name = try getLower(fba.allocator(), header_name);

    if (headers.values.get(lower_name)) |header_values| {
        return HeaderValueIterator{
            .value_ranges = header_values.items,
            .data = headers.data.items,
        };
    }

    return null;
}

pub fn getFirstValue(headers: *Headers, header_name: []const u8) ?[]const u8 {
    var iter = headers.getHeader(header_name) catch return null;
    if (iter) |*i| {
        return i.next();
    }
    return null;
}

pub fn iterator(headers: *Headers) HeaderIterator {
    return HeaderIterator{
        .headers = headers,
    };
}

fn addData(headers: *Headers, value: anytype) !StringRange {
    const value_is_str = comptime std.meta.trait.isZigString(@TypeOf(value));
    const data_start_len = headers.data.items.len;

    var writer = headers.data.writer(headers.allocator);
    if (comptime value_is_str) {
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

fn getLower(allocator: Allocator, header_name: []const u8) ![]const u8 {
    // find the min between the length of the input vs. the length of the temp buffer
    var copy_buffer = try allocator.alloc(u8, header_name.len);
    for (header_name) |c, index| {
        copy_buffer[index] = std.ascii.toLower(c);
    }

    return copy_buffer;
}
