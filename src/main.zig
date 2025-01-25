const std = @import("std");
const clap = @import("clap");

pub fn main() !void {
    // 初始化通用分配器
    const allocator = std.heap.page_allocator;

    // 定义命令行参数
    const params = comptime clap.parseParamsComptime(
        \\-h, --help     显示帮助信息
        \\-n, --name <str>  您的名字
        \\
    );

    var diag = clap.Diagnostic{};
    var parser = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer parser.deinit();

    if (parser.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    if (parser.args.name) |name| {
        std.debug.print("Hello, {s}!\n", .{name});
    } else {
        std.debug.print("Hello, World!\n", .{});
    }
}
