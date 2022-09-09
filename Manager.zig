const specs = @import("specs.zig");
const std = @import("std");
const log = std.log;

const Manager = @This();
const Self = @This();

allocator: std.mem.Allocator,
spec: specs.Spec,

pub fn install(self: *Self) !void {
    log.debug("have {d} plugins", .{self.spec.plugins.count()});
    var iter = self.spec.plugins.iterator();
    while (iter.next()) |entry| {
        const plugin = entry.value_ptr.*;

        switch (plugin.repo) {
            .git => |repo| {
                var args: ExecuteParams = blk: {
                    const as = if (repo.as) |as| as else plugin.name;

                    var root_dir = try mustOpenDir(self.spec.root);
                    errdefer root_dir.close();

                    const stat: ?std.fs.File.Stat = root_dir.statFile(as) catch |err| switch (err) {
                        error.FileNotFound => null,
                        else => unreachable,
                    };

                    if (stat != null) {
                        defer root_dir.close();
                        log.info("plugin {s}: installed already", .{plugin.name});
                        continue;
                    }

                    var cmd = std.ArrayList([]const u8).init(self.allocator);
                    errdefer cmd.deinit();

                    try cmd.appendSlice(&.{ "git", "clone", "--single-branch", repo.uri, as });

                    break :blk .{ .argv = cmd.toOwnedSlice(), .cwd_dir = root_dir };
                };
                defer self.allocator.free(args.argv);
                defer args.cwd_dir.close();

                log.info("plugin {s}: cloning", .{plugin.name});
                try self.run(args);
            },
            .dir => |repo| try self.checkDirPlugin(plugin, repo),
        }
    }
}

pub fn update(self: *Self) !void {
    var iter = self.spec.plugins.iterator();
    while (iter.next()) |entry| {
        const plugin = entry.value_ptr.*;
        switch (plugin.repo) {
            .git => |repo| {
                var args: ExecuteParams = args: {
                    const as = if (repo.as) |as| as else plugin.name;

                    var root_dir = try mustOpenDir(self.spec.root);
                    errdefer root_dir.close();

                    const stat: ?std.fs.File.Stat = root_dir.statFile(plugin.name) catch |err| switch (err) {
                        error.FileNotFound => null,
                        else => unreachable,
                    };

                    var cmd = std.ArrayList([]const u8).init(self.allocator);
                    errdefer cmd.deinit();

                    var cwd_dir: std.fs.Dir = undefined;

                    if (stat) |_| {
                        cwd_dir = try root_dir.openDir(repo.project, .{});
                        log.debug("cwd={s}", .{repo.project});
                        try cmd.appendSlice(&.{ "git", "pull", "origin", "--ff-only" });
                    } else {
                        cwd_dir = root_dir;
                        log.debug("cwd={s}", .{self.spec.root});
                        try cmd.appendSlice(&.{ "git", "clone", "--single-branch", repo.uri, as });
                    }

                    break :args .{ .argv = cmd.toOwnedSlice(), .cwd_dir = cwd_dir };
                };
                defer self.allocator.free(args.argv);
                defer args.cwd_dir.close();

                log.info("plugin {s}: updating", .{plugin.name});
                try self.run(args);
            },
            .dir => |repo| try self.checkDirPlugin(plugin, repo),
        }
    }
}

pub fn clean(self: Self) !void {
    _ = self;
    unreachable;
}

fn checkDirPlugin(self: Self, plugin: specs.Plugin, repo: specs.Repo.Dir) !void {
    var root_dir = try mustOpenDir(self.spec.root);
    defer root_dir.close();

    const stat: ?std.fs.File.Stat = root_dir.statFile(repo.project) catch |err| switch (err) {
        error.FileNotFound => null,
        else => unreachable,
    };
    if (stat) |_| {
        log.err("plugin {s}: not exists, dir={s}", .{ plugin.name, repo.uri });
    } else {
        log.info("plugin {s}: exists, dir={s}", .{ plugin.name, repo.uri });
    }
}

const executor = struct {
    // todo: process pool
    // todo: proxy setup when cloning
    // todo: libgit2 bind rather than childprocess, but it really matters?
    // todo: childprocess timeout 1min
};

const ExecuteParams = struct {
    argv: []const []const u8,
    cwd_dir: std.fs.Dir,
};

fn run(self: Self, params: ExecuteParams) !void {
    log.debug("executing argv={s}", .{params.argv});
    var child = std.ChildProcess.init(params.argv, self.allocator);
    child.cwd_dir = params.cwd_dir;
    try child.spawn();
    switch (try child.wait()) {
        .Exited => |exit_code| log.info("done: {d}", .{exit_code}),
        .Signal => |signal| log.err("term.signal {d}", .{signal}),
        .Stopped => |stopped| log.err("term.stopped {d}", .{stopped}),
        else => unreachable,
    }
}

fn mustOpenDir(path: []const u8) !std.fs.Dir {
    // todo: possible simplification method: std.fs.Dir.makeOpenPath()
    return std.fs.openDirAbsolute(path, .{}) catch |err| open: {
        switch (err) {
            error.FileNotFound => {
                try std.fs.makeDirAbsolute(path);
                break :open try std.fs.openDirAbsolute(path, .{});
            },
            else => unreachable,
        }
    };
}
