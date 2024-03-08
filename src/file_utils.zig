const std = @import("std");
const logger = @import("logger.zig");
const log = logger.get(.file_reader);
const unicode = std.unicode;

pub fn readFile(comptime file_name: []const u8, allocator: std.mem.Allocator) anyerror![]u8 {
    const dir = std.fs.cwd();
    const path = try dir.realpathAlloc(allocator, ".");
    defer allocator.free(path);

    var pages_path = try logger.combineStrings(path, "\\pages\\", allocator);
    defer allocator.free(pages_path);

    var actual_path = try logger.combineStrings(pages_path, file_name, allocator);
    defer allocator.free(actual_path);

    log.warn("path:{s}", .{actual_path});

    var file = try std.fs.openFileAbsolute(actual_path, .{});
    defer file.close();

    const items = try file.readToEndAlloc(allocator, 8192);
    return items;
}
