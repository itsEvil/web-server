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

var route_map: std.StringHashMap(*const fn (send: usize) []const u8) = undefined;
var allocator: std.mem.Allocator = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    allocator = gpa.allocator();

    try index_page.init(allocator);
    try error_page.init(allocator);

    route_map = std.StringHashMap(*const fn (send: usize) []const u8).init(allocator);
    try addRoutes();
    //try route_map.put("/favicon.ico", index_page.get);

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

    findRoute(response) catch |err| {
        log.err("FindRoute::{any}", .{err});
        try sendErrorPage(response);
    };

    if (response.state == .responded)
        try response.finish();
}

fn findRoute(response: *http.Server.Response) !void {
    const target = response.request.target;
    try sendPage(target, response);
}

fn sendPage(endpoint: []const u8, response: *http.Server.Response) !void {
    log.debug("endpoint:{s}", .{endpoint});
    const endpoint_found = route_map.get(endpoint);
    if (endpoint_found) |endpoint_fn| {
        var buf: []const u8 = endpoint_fn(1);
        if (std.mem.endsWith(u8, endpoint, ".css")) {
            try response.headers.append("content-type", "text/css");
            buf = endpoint_fn(0);
        } else {
            try response.headers.append("content-type", "text/html");
        }
        if (response.state == .waited) //If waited then we need to send headers
            try response.do();

        if (response.request.method != .HEAD) {
            try response.writeAll(buf);
        }
    } else return error.NotFound;
}

fn sendErrorPage(response: *http.Server.Response) !void {
    try sendPage("/error", response);
}
