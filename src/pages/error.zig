const std = @import("std");
const Response = std.http.Server.Response;
const Reader = @import("../file_utils.zig");
const logger = @import("../logger.zig");
const log = logger.get(.index);
const root = @import("root");
var css: []u8 = "";
var html: []u8 = "";

var alloc: std.mem.Allocator = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    alloc = allocator;

    css = try Reader.readFile("error\\style.css", allocator);
    html = try Reader.readFile("error\\page.html", allocator);
}

pub fn deinit() void {
    alloc.free(css);
    alloc.free(html);
}

pub fn get(options: root.EndpointOptions) []const u8 {
    return if (options.send == 0) css else if (options.send == 1) html else unreachable;
}
