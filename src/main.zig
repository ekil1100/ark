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

    const full_repo_path = try fs.path.join(allocator, &[_][]const u8{ config.workspace, config.repo });
    defer allocator.free(full_repo_path);

    const command = [_][]const u8{
        "python",
        "ark.py",
        try std.fmt.allocPrint(allocator, "{s}.{s}", .{ config.platform, config.mode }),
    };

    std.debug.print("{s}\n", .{std.mem.join(allocator, " ", &command) catch "Failed to join command"});

    var child = process.Child.init(&command, allocator);

    child.cwd = full_repo_path;
    std.debug.print("{s}\n", .{full_repo_path});

    _ = try child.spawnAndWait();
}

const SubCommands = enum {
    help,
    build,
};

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help        print help information
    \\<command>
    \\
);

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var diag = clap.Diagnostic{};
    var parser = clap.parse(clap.Help, &main_params, main_parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer parser.deinit();

    if (parser.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});

    if (parser.positionals.len == 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});
    }

    const command = parser.positionals[0];
    switch (command) {
        .help => return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{}),
        .build => {
            const config = try readConfig(allocator);
            try execBuild(config);
        },
    }
}
