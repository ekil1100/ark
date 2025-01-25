const std = @import("std");
const clap = @import("clap");
const process = std.process;
const fs = std.fs;

const Config = struct {
    workspace: []const u8,
    repo: []const u8,
    mode: []const u8,
    env: []const u8,
    platform: []const u8,
};

const SubCommands = enum {
    help,
    math,
};

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help        显示帮助信息
    \\build             执行构建命令
    \\
);

fn readConfig(allocator: std.mem.Allocator) !Config {
    // 读取配置文件
    const file = try fs.cwd().openFile("config.toml", .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // 解析 TOML
    var config = Config{
        .workspace = "",
        .repo = "",
        .mode = "debug",
        .env = "standalone",
        .platform = "x64",
    };

    var lines = std.mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        var trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t\"");
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t\"");

            if (std.mem.eql(u8, key, "workspace")) {
                config.workspace = try allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "repo")) {
                config.repo = try allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "mode")) {
                config.mode = try allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "env")) {
                config.env = try allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "platform")) {
                config.platform = try allocator.dupe(u8, value);
            }
        }
    }

    return config;
}

fn execBuild(config: Config) !void {
    const allocator = std.heap.page_allocator;

    // 构建完整的 repo 路径
    const full_repo_path = try fs.path.join(allocator, &[_][]const u8{ config.workspace, config.repo });
    defer allocator.free(full_repo_path);

    // 创建命令
    var child = process.Child.init(&[_][]const u8{
        "python",
        "ark.py",
        try std.fmt.allocPrint(allocator, "{s}.{s}", .{ config.platform, config.mode }),
    }, allocator);

    // 设置工作目录为完整的 repo 路径
    child.cwd = full_repo_path;

    // 执行命令
    _ = try child.spawnAndWait();
}

pub fn main() !void {
    // 初始化通用分配器
    const allocator = std.heap.page_allocator;

    var diag = clap.Diagnostic{};
    var parser = clap.parse(clap.Help, &main_params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer parser.deinit();

    if (parser.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});

    if (parser.args.build) {
        // 读取配置
        const config = try readConfig(allocator);
        // 执行构建
        try execBuild(config);
    }
}
