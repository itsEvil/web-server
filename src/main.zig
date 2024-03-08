const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;

const index_page = @import("pages/index.zig");
const error_page = @import("pages/error.zig");

const log_utils = @import("logger.zig");
const log = log_utils.get(.main);

const file_checker = @import("file_checker.zig");

const server_addr = "127.0.0.1";
const server_port = 8080;

const hot_reload: bool = true;

var route_map: std.StringHashMap(*const fn (options: EndpointOptions) []const u8) = undefined;
var allocator: std.mem.Allocator = undefined;

pub const EndpointOptions = struct { send: usize };

pub const ErrorOptions = struct {
    error_int: []const u8 = "404",
    error_desc: []const u8 = "Page not found",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    allocator = gpa.allocator();

    try index_page.init(allocator);
    try error_page.init(allocator);

    route_map = std.StringHashMap(*const fn (options: EndpointOptions) []const u8).init(allocator);
    try addRoutes();

    var server = http.Server.init(allocator, .{});
    defer server.deinit();

    log.warn("Listening at {s}:{d}", .{ server_addr, server_port });
    const address = std.net.Address.parseIp4(server_addr, server_port) catch unreachable;
    try server.listen(address);

    runServer(&server) catch |err| {
        // Handle server errors.
        log.err("server error: {}\n", .{err});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
        std.os.exit(1);
    };
}

pub fn addRoutes() !void {
    try route_map.put("/", index_page.get);
    try route_map.put("/index", index_page.get);
    try route_map.put("/index.html", index_page.get);
    try route_map.put("/style.css", index_page.get);
    try route_map.put("/error", error_page.get);
    try route_map.put("/error/page.html", error_page.get);
    try route_map.put("/error/style.css", error_page.get);
}

pub fn reload() !void {
    log.warn("reloading pages", .{});

    index_page.deinit();
    try index_page.init(allocator);

    error_page.deinit();
    try error_page.init(allocator);
}

// Run the server and handle incoming requests.
fn runServer(server: *http.Server) !void {
    outer: while (true) {
        // Accept incoming connection.
        var response = try server.accept(.{
            .allocator = allocator,
        });
        defer response.deinit();

        if (hot_reload)
            try file_checker.main();

        // Handle errors during request processing.
        response.wait() catch |err| switch (err) {
            else => {
                log.err("wait::{any}", .{err});
                continue :outer;
            },
        };

        // Process the request.
        handleRequest(&response) catch |err| switch (err) {
            else => {
                log.err("handle::{any}", .{err});
                continue :outer;
            },
        };
    }
}

// Handle an individual request.
fn handleRequest(response: *http.Server.Response) !void {
    // Log the request details.
    response.transfer_encoding = .chunked;
    log.info("{s} {s} {s}", .{ @tagName(response.request.method), @tagName(response.request.version), response.request.target });

    // Set "connection" header to "keep-alive" if present in request headers.
    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    const isCss = std.mem.endsWith(u8, response.request.target, ".css");
    if (isCss) {
        try response.headers.append("content-type", "text/css");
    } else try response.headers.append("content-type", "text/html");

    findRoute(response, .{ .send = (if (isCss) 0 else 1) }) catch |err| {
        log.err("FindRoute::{any}", .{err});
        if (isCss) {
            try sendErrorCss(response);
        } else try sendErrorPage(response, .{ .error_int = "404", .error_desc = "Page not found" });
    };

    if (response.state == .responded)
        try response.finish();
}

fn findRoute(response: *http.Server.Response, options: EndpointOptions) !void {
    const target = response.request.target;
    const page = try getPage(target, options);
    try sendPage(page, response);
}

fn getPage(endpoint: []const u8, options: EndpointOptions) ![]const u8 {
    log.debug("endpoint:{s}", .{endpoint});
    const endpoint_found = route_map.get(endpoint);
    if (endpoint_found) |endpoint_fn| {
        return endpoint_fn(options);
    } else return error.NotFound;
}

fn sendPage(buf: []const u8, response: *http.Server.Response) !void {
    if (response.state == .waited) //If waited then we need to send headers
        try response.do();

    if (response.request.method != .HEAD) {
        try response.writeAll(buf);
    }
}

fn sendErrorPage(response: *http.Server.Response, options: ErrorOptions) !void {
    const html = try getPage("/error", .{ .send = 1 });

    const size = std.mem.replacementSize(u8, html, "{error_int}", options.error_int);
    const buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);

    _ = std.mem.replace(u8, html, "{error_int}", options.error_int, buf);
    const desc_size = std.mem.replacementSize(u8, buf, "{error_desc}", options.error_desc);
    const desc_buf = try allocator.alloc(u8, desc_size);
    defer allocator.free(desc_buf);
    _ = std.mem.replace(u8, buf, "{error_desc}", options.error_desc, desc_buf);

    try sendPage(desc_buf, response);
}

fn sendErrorCss(response: *http.Server.Response) !void {
    const page = try getPage("/error/style.css", .{ .send = 0 });
    try sendPage(page, response);
}
