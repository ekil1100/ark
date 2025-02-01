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
    var child = process.Child.init(&command, allocator);
    child.cwd = full_repo_path;
    std.debug.print("{s}\n", .{full_repo_path});
    std.debug.print("{s}\n", .{std.mem.join(allocator, " ", &command) catch "Failed to join command"});
    _ = try child.spawnAndWait();
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // const config = try readConfig(allocator);

    // const SubCommands = enum {
    //     help,
    //     build,
    //     config,
    // };

    const parsers = clap.parsers.default;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-n, --number <usize>   An option parameter, which takes a value.
        \\-s, --string <str>...  An option parameter which can be specified multiple times.
        \\<str>...
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if (res.positionals.len == 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    for (res.positionals) |pos| {
        std.debug.print("{s}\n", .{pos});
    }

    // const command = res.positionals[0];

    // switch (command) {
    //     .help => return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{}),
    //     .build => try execBuild(config),
    //     .config => {
    //         if (res.positionals.len < 3) {
    //             std.debug.print("Usage: ark config <key> <value>\n", .{});
    //             return;
    //         }
    //         for (res.positionals) |pos| {
    //             std.debug.print("{s}\n", .{pos});
    //         }
    //     },
    // }
}
