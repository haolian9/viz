const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const testing = std.testing;

const bits = usize;
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
};

const compound = std.ComptimeStringMap(bits, .{
    .{ "base", Part.compound(&[_]Part{.base}) },
    .{ "code", Part.compound(&[_]Part{ .base, .lsp, .treesitter, .code }) },
    .{ "mostbeloved", Part.compound(&[_]Part{ .base, .lsp, .treesitter, .code, .python, .zig, .lua, .clang, .mostbeloved }) },
});

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

pub fn main() !void {
    print("base=({d}, {d}, {d}), code={d}, mostbeloved={d}\n", .{
        compound.get("base").?,
        @enumToInt(Part.base),
        @enumToInt(Profile.base),
        compound.get("code").?,
        compound.get("mostbeloved").?,
    });
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
