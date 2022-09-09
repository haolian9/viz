const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const testing = std.testing;

pub const bits = usize;
const nbits = std.math.Log2Int(bits);

// zig fmt: off
const Part = enum(nbits) {
    // tier 0
    base,
    // tier 1
    git, wiki, lsp, treesitter,
    // tier 2
    code,
    // tier 3
    python, zig, lua, go, rust, nim, ansible, php, clang,
    // tier 4
    mostbeloved,
    // tier 5
    @"python.jedi",

    fn compound(parts: []const Part) bits {
        var val: bits = 0;
        const base: bits = 1;
        for (parts) |p| {
            val |= base << @enumToInt(p);
        }
        return val;
    }

    fn compoundAll() bits {
        var val: bits = 0;
        const base: bits = 1;
        inline for (std.meta.fields(Part)) |field| {
            val |= base << field.value;
        }
        return val;
    }
};

pub const Profile = enum(bits) {

    // tier 0
    base = as(null, &.{"base"}),

    // tier 1
    git = as(.git, &.{"base"}),
    wiki = as(.wiki, &.{"base"}),
    lsp = as(.lsp, &.{"base"}),
    treesitter = as(.treesitter, &.{"base"}),

    // tier 2
    code = as(.code, &.{"code"}),

    // tier 3
    python = as(.python, &.{"code"}),
    zig = as(.zig, &.{"code"}),
    lua = as(.lua, &.{"code"}),
    go = as(.go, &.{"code"}),
    rust = as(.rust, &.{"code"}),
    nim = as(.nim, &.{"code"}),
    ansible = as(.ansible, &.{"code"}),
    php = as(.php, &.{"code"}),
    clang = as(.clang, &.{"code"}),

    // tier 4
    mostbeloved = as(null, &.{"mostbeloved"}),

    // tier 5
    @"python.jedi" = as(.@"python.jedi", null),

    all = as(null, &.{"all"}),

    const compound = std.ComptimeStringMap(bits, .{
        .{ "base", Part.compound(&[_]Part{.base}) },
        .{ "code", Part.compound(&[_]Part{ .base, .lsp, .treesitter, .code }) },
        .{ "mostbeloved", Part.compound(&[_]Part{ .base, .lsp, .treesitter, .code, .python, .zig, .lua, .clang, .mostbeloved }) },
        .{ "all", Part.compoundAll() },
    });

    pub fn has(self: Profile, another: Profile) bool {
        return @enumToInt(self) & @enumToInt(another) == @enumToInt(another);
    }

    fn as(count: ?Part, profiles: ?[]const []const u8) bits {
        var val = if (count) |c| @as(bits, 1) << @enumToInt(c) else @as(bits, 0);
        if (profiles) |certain| {
            for (certain) |p| {
                if (compound.get(p)) |pv| {
                    val |= pv;
                } else unreachable;
            }
        }
        return val;
    }
};

pub const Profiles = struct {
    val: bits,

    const Self = @This();

    pub fn init(profiles: []const Profile) Profiles {
        var val: bits = 0;
        for (profiles) |p| {
            val |= @enumToInt(p);
        }
        return .{.val = val};
    }

    pub fn has(self: Profiles, profile: Profile) bool {
        return self.val & @enumToInt(profile) == @enumToInt(profile);
    }
};


pub fn main() !void {
    print("base=({d}, {d}, {d}), code={d}, mostbeloved={d}\n", .{
        Profile.compound.get("base").?,
        @enumToInt(Part.base),
        @enumToInt(Profile.base),
        Profile.compound.get("code").?,
        Profile.compound.get("mostbeloved").?,
    });

    inline for (std.meta.fields(Part)) |field| {
        print("* {d}\n", .{field.value});
    }
    print("{d} {d}\n", .{Part.compoundAll(), @enumToInt(Profile.all)});
}

test "Profile api" {
    try testing.expect(@enumToInt(Profile.base) == 1);
    try testing.expect(!Profile.git.has(.lsp));
    try testing.expect(!Profile.lsp.has(.git));
    try testing.expect(Profile.code.has(.lsp));
    try testing.expect(Profile.code.has(.base));
    try testing.expect(!Profile.code.has(.git));
}

// asyncrun: zig test
// asyncrun: zig run
