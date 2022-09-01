const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

const Repo = union {
    git: Git,
    dir: Dir,

    const maxsize = std.fs.MAX_PATH_BYTES;

    const Dir = struct {
        uri: []const u8,
        root: []const u8,
        project: []const u8,

        fn asstr(self: Git, buf: *[maxsize]u8) ![]const u8 {
            return try std.fmt.bufPrint(buf, "{}{}{}", .{ self.root, std.fs.path.sep, self.project });
        }

        fn init(path: []const u8) !Dir {
            // /srv/playground/viz
            if (!std.mem.startsWith(u8, path, "/")) return error.NotAbsolutePath;
            if (std.mem.endsWith(u8, path, "/")) return error.PathTrailingSlash;
            const sep = if (std.mem.lastIndexOf(u8, path, "/")) |pos| pos else return error.PathMissingRoot;
            return .{ .uri = path, .root = path[0..sep], .project = path[sep + 1 ..] };
        }
    };

    const Git = struct {
        uri: []const u8,
        protocol: Protocol,
        base: []const u8,
        user: []const u8,
        project: []const u8,
        branch: []const u8,

        // todo: git protocol
        const Protocol = enum {
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

        fn asstr(self: Git, buf: *[maxsize]u8) ![]const u8 {
            return try std.fmt.bufPrint(buf, "{s}{s}{s}{s}/{s}", .{ self.protocol.prefix(), self.base, self.protocol.sep1(), self.user, self.project });
        }

        fn init(uri: []const u8, branch: []const u8) !Git {
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
            // todo: purify
            const project_end = uri.len;
            if (project_start == project_end) return error.UriMissingProject;
            const project = uri[project_start..project_end];

            return .{
                .uri = uri,
                .protocol = protocol,
                .base = base,
                .user = user,
                .project = project,
                .branch = branch,
            };
        }
    };
};

const Plugin = struct {
    /// unique name
    name: []const u8,
    // entry dir in repo
    entry: ?[]const u8 = null,
    repo: Repo,
    // todo: detect cyclic depends, but does it really matter in the perspective of a nvim plugin manager?
    //depends: ?[]const *const Plugin = null,
    depends: ?[]const []const u8 = null,
};

const Spec = struct {
    // the dir to save all the files of plugins.
    root: []const u8,
    plugins: PluginTable,

    const PluginTable = std.StringHashMap(Plugin);

    // todo: []*const Plugin
    fn init(allocator: std.mem.Allocator, root: []const u8, plugins: []*Plugin) !Spec {
        var ptable = PluginTable.init(allocator);
        errdefer ptable.deinit();
        for (plugins) |p| {
            print("{s}: {any}\n", .{ p.name, @TypeOf(p) });
            var gop = try ptable.getOrPut(p.name);
            if (gop.found_existing) return error.DuplicatePluginsFound;
            gop.value_ptr = p;
        }

        return Spec{ .root = root, .plugins = ptable };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(!gpa.deinit());

    const allocator = gpa.allocator();

    // todo: default branch
    // todo: default name
    var plenary = try allocator.create(Plugin);
    defer allocator.destroy(plenary);
    plenary.* = .{
        .name = "plenary",
        .repo = .{ .git = try Repo.Git.init("https://github.com/haolian9/kite.nvim.git", "master") },
    };
    var kite = try allocator.create(Plugin);
    defer allocator.destroy(kite);
    kite.* = .{
        .name = "kite",
        .repo = .{ .git = try Repo.Git.init("https://github.com/haolian9/kite.nvim.git", "master") },
        .depends = &.{"plenary"},
    };
    var viz = try allocator.create(Plugin);
    defer allocator.destroy(viz);
    viz.* = .{
        .name = "viz",
        .repo = .{ .git = try Repo.Git.init("https://github.com/haolian9/kite.nvim.git", "master") },
        .depends = &.{"plenary"},
    };

    var spec = try Spec.init(allocator, "/tmp/viz", &.{ plenary, kite, viz });
    defer spec.plugins.deinit();

    print("{any}", .{spec});
}
