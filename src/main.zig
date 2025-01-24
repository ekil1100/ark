const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});
}

test "simple test" {
    try std.testing.expectEqual(10, 3 + 7);
}
