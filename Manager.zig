const specs = @import("specs.zig");
const std = @import("std");
const log = std.log;
const profiles = @import("profiles.zig");

const Manager = @This();
const Self = @This();

allocator: std.mem.Allocator,
spec: specs.Spec,

pub fn install(self: *Self) !void {
    log.debug("have {d} plugins", .{self.spec.plugins.count()});
    var iter = self.spec.iterator();
    while (iter.next()) |plugin| {
        switch (plugin.repo) {
            .git => |repo| {
                var args: ExecuteParams = blk: {
                    const as = if (repo.as) |as| as else plugin.name;

                    var root_dir = try mustOpenDir(self.spec.root);
                    errdefer root_dir.close();

                    const stat: ?std.fs.File.Stat = root_dir.statFile(as) catch |err| switch (err) {
                        error.FileNotFound => null,
                        else => return err,
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
    var iter = self.spec.iterator();
    while (iter.next()) |plugin| {
        switch (plugin.repo) {
            .git => |repo| {
                var args: ExecuteParams = args: {
                    const as = if (repo.as) |as| as else plugin.name;

                    var root_dir = try mustOpenDir(self.spec.root);
                    errdefer root_dir.close();

                    const stat: ?std.fs.File.Stat = root_dir.statFile(plugin.name) catch |err| switch (err) {
                        error.FileNotFound => null,
                        else => return err,
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
        else => return err,
    };
    if (stat) |_| {
        log.err("plugin {s}: not exists, dir={s}", .{ plugin.name, repo.uri });
    } else {
        log.info("plugin {s}: exists, dir={s}", .{ plugin.name, repo.uri });
    }
}

const Executor = struct {
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
        else => unreachable,
    }
}

fn mustOpenDir(path: []const u8) !std.fs.Dir {
    return std.fs.openDirAbsolute(path, .{}) catch |err| open: {
        switch (err) {
            error.FileNotFound => {
                try std.fs.makeDirAbsolute(path);
                break :open try std.fs.openDirAbsolute(path, .{});
            },
            else => return err,
        }
    };
}

const VimDirIterator = struct {
    dir: std.fs.IterableDir,
    iter: std.fs.IterableDir.Iterator,

    const known_vim_dirs = std.ComptimeStringMap(void, .{
        // vim
        .{"autoload"},
        .{"colors"},
        .{"compiler"},
        .{"ftplugin"},
        .{"ftdetect"},
        .{"indent"},
        .{"plugin"},
        .{"rplugin"},
        .{"spell"},
        .{"syntax"},
        // todo: queries/x/*.scm
        .{"queries"},
        // todo: after/x/**.{lua,vim}
        .{"after"},
        // todo: lus/x/**.lua
        .{"lua"},
        // todo: ultisnips/pythonx
    });

    fn init(dir: std.fs.IterableDir) VimDirIterator {
        return .{ .dir = dir, .iter = dir.iterate() };
    }

    fn next(self: *VimDirIterator) !?std.fs.IterableDir.Entry {
        while (try self.iter.next()) |entry| {
            switch (entry.kind) {
                .Directory => {
                    if (!known_vim_dirs.has(entry.name)) {
                        log.debug("skipped {s}", .{entry.name});
                        continue;
                    }
                    return entry;
                },
                else => continue,
            }
        }
        return null;
    }
};

pub fn collapse(self: Self, output_path: []const u8) !void {
    var output_dir = try mustOpenDir(output_path);
    defer output_dir.close();

    var root_dir = try mustOpenDir(self.spec.root);
    defer root_dir.close();

    var output_subdirs = std.StringHashMap(std.fs.Dir).init(self.allocator);
    defer output_subdirs.deinit();
    defer {
        var iter = output_subdirs.valueIterator();
        while (iter.next()) |subdir| {
            subdir.close();
        }
    }
    inline for (VimDirIterator.known_vim_dirs.kvs) |kv| {
        const gop = try output_subdirs.getOrPut(kv.key);
        if (gop.found_existing) unreachable;
        gop.value_ptr.* = output_dir.openDir(kv.key, .{}) catch |err| switch (err) {
            error.FileNotFound => try output_dir.makeOpenPath(kv.key, .{}),
            else => return err,
        };
    }

    var iter = self.spec.iterate();
    while (iter.next()) |plugin| {
        var repo_dir: std.fs.IterableDir = switch (plugin.repo) {
            .git => |repo| try root_dir.openIterableDir(if (repo.as) |as| as else repo.project, .{}),
            .dir => |repo| try std.fs.openIterableDirAbsolute(repo.uri, .{}),
        };
        defer repo_dir.close();

        var repo_iter = VimDirIterator.init(repo_dir);
        while (try repo_iter.next()) |entry| {
            var entry_dir = try repo_dir.dir.openIterableDir(entry.name, .{});
            defer entry_dir.close();

            // todo: copy tree
            // const subdir = output_subdirs.get(entry.name) orelse unreachable;
            var entry_iter = entry_dir.iterate();
            while (try entry_iter.next()) |e2| {
                switch (e2.kind) {
                    .Directory => {
                        log.debug("found {s}/{s}", .{ entry.name, e2.name });
                    },
                    else => {},
                }
            }
        }
    }
}
