const std = @import("std");
const Response = std.http.Server.Response;
const Reader = @import("../file_utils.zig");
const logger = @import("../logger.zig");
const log = logger.get(.index);

var css: []u8 = "";
var html: []u8 = "";

var alloc: std.mem.Allocator = undefined;

pub const ErrorOptions = struct {
    int: []const u8 = "404",
    desc: []const u8 = "Page not found",
};

pub fn init(allocator: std.mem.Allocator, options: ErrorOptions) !void {
    alloc = allocator;

    css = try Reader.readFile("error\\style.css", allocator);
    const page_html = try Reader.readFile("error\\page.html", allocator);

    const size = std.mem.replacementSize(u8, page_html, "{error_int}", options.int);

    const buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);

    _ = std.mem.replace(u8, page_html, "{error_int}", options.int, buf);
    const desc_size = std.mem.replacementSize(u8, buf, "{error_desc}", options.desc);
    const desc_buf = try allocator.alloc(u8, desc_size);
    _ = std.mem.replace(u8, buf, "{error_desc}", options.desc, desc_buf);
    html = desc_buf; //freed in deinit()
}

pub fn deinit() void {
    alloc.free(css);
    alloc.free(html);
}

pub fn get(send: usize) []const u8 {
    return if (send == 0) css else if (send == 1) html else unreachable;
}
