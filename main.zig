const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const specs = @import("specs.zig");
const Manager = @import("Manager.zig");
const log = std.log;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(!gpa.deinit());

    const allocator = gpa.allocator();

    var spec = try specs.Spec.init(allocator, "/home/haoliang/.local/share/nvim/viz", &.{
        // base
        .{ .uri = "https://github.com/lewis6991/impatient.nvim" },
        .{ .uri = "https://github.com/tpope/vim-repeat" },
        .{ .uri = "https://github.com/phaazon/hop.nvim" },
        .{ .uri = "https://github.com/junegunn/vim-easy-align" },
        .{ .uri = "https://github.com/michaeljsmith/vim-indent-object" },
        .{ .uri = "https://github.com/tpope/vim-surround" },

        // lsp
        .{ .uri = "https://github.com/neovim/nvim-lspconfig" },
        .{ .uri = "https://github.com/nvim-lua/plenary.nvim" },
        // .{.uri = "https://github.com/jose-elias-alvarez/null-ls.nvim"},
        //.{ .uri = "/srv/playground/null-ls.nvim" },
        .{ .uri = "https://github.com/haolian9/null-ls.nvim", .branch = "hal", .as = "null-ls-hal" },

        // treesitter
        // .{ .uri = "https://github.com/nvim-treesitter/nvim-treesitter" },
        .{ .uri = "https://github.com/haolian9/nvim-treesitter", .branch = "hal", .as = "nvim-treesitter-hal" },
        //.{ .uri = "https://github.com/nvim-treesitter/nvim-treesitter-refactor" },
        .{ .uri = "https://github.com/haolian9/nvim-treesitter-refactor", .branch = "hal", .as = "nvim-treesitter-refactor-hal" },
        // .{.uri = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects"},
        .{ .uri = "https://github.com/haolian9/nvim-treesitter-textobjects", .branch = "hal", .as = "nvim-treesitter-textobjects-hal" },
        .{ .uri = "https://github.com/nvim-treesitter/playground" },

        // code
        // .{.uri = "https://github.com/ibhagwan/fzf-lua"},
        // .{.uri = "/srv/playground/fzf-lua"},
        .{ .uri = "https://github.com/haolian9/fzf-lua", .branch = "hal", .as = "fzf-lua-hal" },
        .{ .uri = "https://github.com/SirVer/ultisnips" },
        .{ .uri = "https://github.com/skywind3000/asyncrun.vim" },
        .{ .uri = "https://github.com/tpope/vim-commentary" },

        // git
        .{ .uri = "https://github.com/tpope/vim-fugitive" },
        .{ .uri = "https://github.com/junegunn/gv.vim" },

        // wiki
        .{ .uri = "https://github.com/vimwiki/vimwiki" },
    });
    defer spec.deinit();

    // var plugin_iter = spec.plugins.iterator();
    // while (plugin_iter.next()) |entry| {
    //     log.debug("xx * {s}", .{entry.value_ptr.name});
    // }

    var manager = Manager{ .allocator = allocator, .spec = spec };

    try manager.install();
}
