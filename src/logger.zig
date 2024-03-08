const std = @import("std");
const main = @import("main.zig");
const log_std = std.log;

const log_level = log_std.Level.debug;

pub fn get(comptime scope: @Type(.EnumLiteral)) type {
    return struct {
        /// Log an error message. This log level is intended to be used
        /// when something has gone wrong. This might be recoverable or might
        /// be followed by the program exiting.
        pub fn err(
            comptime format: []const u8,
            args: anytype,
        ) void {
            @setCold(true);
            log(.err, scope, format, args);
        }

        /// Log a warning message. This log level is intended to be used if
        /// it is uncertain whether something has gone wrong or not, but the
        /// circumstances would be worth investigating.
        pub fn warn(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.warn, scope, format, args);
        }

        /// Log an info message. This log level is intended to be used for
        /// general messages about the state of the program.
        pub fn info(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.info, scope, format, args);
        }

        /// Log a debug message. This log level is intended to be used for
        /// messages which are only useful for debugging.
        pub fn debug(
            comptime format: []const u8,
            args: anytype,
        ) void {
            log(.debug, scope, format, args);
        }
    };
}

pub fn log(
    comptime level: log_std.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    //if (@intFromEnum(level) < @intFromEnum(log_level))
    //    return;

    const scope_prefix = @tagName(scope) ++ "::";
    const prefix = comptime level.asText() ++ "::" ++ scope_prefix;
    // Print the message to stderr, silently ignoring any errors
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub fn read() !void {
    var buf: [10]u8 = undefined;
    _ = try std.io.getStdIn().reader().readUntilDelimiterOrEof(buf[0..], '\n');
}

pub fn combineStrings(left: []const u8, right: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ left, right });
}