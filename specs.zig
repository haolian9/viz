const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const testing = std.testing;
const profile_types = @import("profiles.zig");

pub const Repo = union(enum) {
    git: Git,
    dir: Dir,

    pub const maxsize = std.fs.MAX_PATH_BYTES;

    pub const Dir = struct {
        uri: []const u8,
        root: []const u8,
        project: []const u8,

        /// :path: /srv/playground/viz
        pub fn init(path: []const u8) !Dir {
            if (!std.mem.startsWith(u8, path, "/")) return error.NotAbsolutePath;
            if (std.mem.endsWith(u8, path, "/")) return error.PathTrailingSlash;

            const sep = if (std.mem.lastIndexOf(u8, path, "/")) |idx| idx else return error.PathMissingRoot;

            return Dir{ .uri = path, .root = path[0..sep], .project = path[sep + 1 ..] };
        }
    };

    pub const Git = struct {
        uri: []const u8,
        protocol: Protocol,
        base: []const u8,
        user: []const u8,
        project: []const u8,
        branch: ?[]const u8,
        as: ?[]const u8,

        pub const Protocol = enum {
            https,
            http,
            git,

            fn prefix(self: Protocol) []const u8 {
                return switch (self) {
                    .https => "https://",
                    .http => "http://",
                    .git => "git@",
                };
            }

            fn sep1(self: Protocol) []const u8 {
                return switch (self) {
                    .https, .http => "/",
                    .git => ":",
                };
            }
        };

        pub fn init(uri: []const u8, branch: ?[]const u8, as: ?[]const u8) !Git {
            // git@gitlab.com:haoliang-incubator/viz.git
            // https://gitlab.com/haoliang-incubator/viz.git
            // git@github.com:haolian9/kite.nvim.git
            // https://github.com/haolian9/kite.nvim.git
            var protocol: Protocol = undefined;
            var tokens: [3][]const u8 = undefined;
            if (std.mem.startsWith(u8, uri, "git@")) {
                protocol = .git;
                tokens = .{ "git@", ":", "/" };
            } else if (std.mem.startsWith(u8, uri, "https://")) {
                protocol = .https;
                tokens = .{ "https://", "/", "/" };
            } else if (std.mem.startsWith(u8, uri, "http://")) {
                protocol = .http;
                tokens = .{ "http://", "/", "/" };
            } else return error.UnsupportedUri;

            const base_start = tokens[0].len + 1;
            const base_end = if (std.mem.indexOfPos(u8, uri, base_start, tokens[1])) |base_end| base_end else return error.UriMissingBase;
            if (base_start == base_end) return error.UriMissingBase;
            const base = uri[base_start..base_end];

            const user_start = base_end + 1;
            const user_end = if (std.mem.indexOfPos(u8, uri, user_start, tokens[2])) |index| index else return error.UriMissingUser;
            if (user_start == user_end) return error.UriMissingUser;
            const user = uri[user_start..user_end];

            const project_start = user_end + 1;
            const project_end = uri.len;
            if (project_start == project_end) return error.UriMissingProject;
            const project = uri[project_start..project_end];

            return Git{
                .uri = uri,
                .protocol = protocol,
                .base = base,
                .user = user,
                .project = project,
                .branch = branch,
                .as = as,
            };
        }
    };
};

// todo: hook
pub const Plugin = struct {
    profile: profile_types.Profile,
    /// unique name
    name: []const u8,
    /// entry dir in the repo
    entry: []const u8,
    repo: Repo,

    pub const InitParams = struct {
        profile: profile_types.Profile,
        uri: []const u8,
        name: ?[]const u8 = null,
        entry: ?[]const u8 = null,
        branch: ?[]const u8 = null,
        as: ?[]const u8 = null,
    };

    pub fn init(params: InitParams) !Plugin {
        var repo: Repo = undefined;
        var name: []const u8 = undefined;
        if (std.mem.startsWith(u8, params.uri, "/")) {
            if (params.branch != null) unreachable;
            repo = .{ .dir = try Repo.Dir.init(params.uri) };
            name = if (params.name) |n| n else repo.dir.project;
        } else {
            repo = .{ .git = try Repo.Git.init(params.uri, params.branch, params.as) };
            name = if (params.name) |n| n else repo.git.project;
        }
        var entry = if (params.entry) |entry| entry else "/";

        return Plugin{
            .profile = params.profile,
            .name = name,
            .entry = entry,
            .repo = repo,
        };
    }
};

pub const Spec = struct {
    allocator: std.mem.Allocator,
    // the dir to save all the files of plugins.
    root: []const u8,
    plugins: PluginTable,
    orders: std.ArrayList([]const u8),
    profiles: profile_types.Profiles,

    const PluginTable = std.StringHashMap(Plugin);

    pub fn init(allocator: std.mem.Allocator, profiles: []const profile_types.Profile, root: []const u8, plugins: []const Plugin.InitParams) !Spec {
        const pros = profile_types.Profiles.init(profiles);

        var ptable = PluginTable.init(allocator);
        errdefer ptable.deinit();

        var orders = std.ArrayList([]const u8).init(allocator);
        errdefer orders.deinit();

        for (plugins) |pargs| {
            const p = try Plugin.init(pargs);
            try orders.append(p.name);
            const gop = try ptable.getOrPut(p.name);
            if (gop.found_existing) return error.DuplicatePluginsFound;
            gop.value_ptr.* = p;
        }

        return Spec{ .allocator = allocator, .root = root, .plugins = ptable, .orders = orders, .profiles = pros };
    }

    const Iterator = struct {
        context: Spec,
        index: usize,

        pub fn next(self: *Iterator) ?Plugin {
            while (self.index < self.context.orders.items.len) {
                defer self.index += 1;
                const name = self.context.orders.items[self.index];
                const plugin = self.context.plugins.get(name).?;
                if (self.context.profiles.has(plugin.profile)) return plugin;
            }
            return null;
        }
    };

    pub fn iterate(self: Spec) Iterator {
        return .{ .context = self, .index = 0 };
    }

    pub fn deinit(self: *Spec) void {
        self.plugins.deinit();
        self.orders.deinit();
    }
};

pub const VimRtp = struct {
    allocator: std.mem.Allocator,
    paths: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) VimRtp {
        var paths = std.ArrayList([]const u8).init(allocator);
        return .{
            .allocator = allocator,
            .paths = paths,
        };
    }

    pub fn deinit(self: Self) void {
        for (self.paths.items) |path| self.allocator.free(path);
        self.paths.deinit();
    }

    pub fn append(self: *Self, parts: []const []const u8) !void {
        const path = try std.fs.path.join(self.allocator, parts);
        try self.paths.append(path);
    }

    pub fn dump(self: Self, writer: anytype) !void {
        try std.json.stringify(self.paths.items, .{}, writer);
    }

    pub fn fromSpec(allocator: std.mem.Allocator, spec: Spec) !VimRtp {
        var rtp = VimRtp.init(allocator);
        errdefer rtp.deinit();

        var iter = spec.iterate();
        while (iter.next()) |plugin| {
            switch (plugin.repo) {
                .git => |repo| {
                    const as = if (repo.as) |as| as else plugin.name;
                    try rtp.append(&.{ spec.root, as });
                },
                .dir => |repo| {
                    try rtp.append(&.{repo.uri});
                },
            }
        }

        return rtp;
    }
};

test "Plugin.init" {
    const p1 = try Plugin.init(.{ .uri = "https://github.com/lewis6991/impatient.nvim" });
    const p2 = try Plugin.init(.{ .uri = "https://github.com/tpope/vim-repeat" });
    const p3 = try Plugin.init(.{ .uri = "https://github.com/phaazon/hop.nvim" });
    const p4 = try Plugin.init(.{ .uri = "/github.com/phaazon/hop.nvim" });

    inline for (.{ p1, p2, p3, p4 }) |p| {
        switch (p.repo) {
            .git => |git| assert(git.project.len > 0),
            .dir => |dir| assert(dir.project.len > 0),
        }
    }
}

test "spec.init" {
    const allocator = testing.allocator;

    var spec = try Spec.init(allocator, "/tmp/viz", &.{
        .{ .uri = "https://github.com/lewis6991/impatient.nvim" },
        .{ .uri = "https://github.com/tpope/vim-repeat" },
        .{ .uri = "https://github.com/phaazon/hop.nvim" },
        .{ .uri = "/github.com/phaazon/hop.nvim2" },
    });
    defer spec.deinit();

    assert(spec.plugins.count() == 4);
}

// asyncrun: zig test
