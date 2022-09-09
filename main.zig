const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const log = std.log;

const specs = @import("specs.zig");
const Manager = @import("Manager.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(!gpa.deinit());

    const allocator = gpa.allocator();

    var spec = try specs.Spec.init(allocator, &.{.base}, "/home/haoliang/.local/share/nvim/viz", &.{
        .{ .profile = .base, .uri = "https://github.com/lewis6991/impatient.nvim" },
        .{ .profile = .base, .uri = "https://github.com/tpope/vim-repeat" },
        .{ .profile = .base, .uri = "https://github.com/phaazon/hop.nvim" },
        .{ .profile = .base, .uri = "https://github.com/junegunn/vim-easy-align" },
        .{ .profile = .base, .uri = "https://github.com/michaeljsmith/vim-indent-object" },
        .{ .profile = .base, .uri = "https://github.com/tpope/vim-surround" },

        .{ .profile = .lsp, .uri = "https://github.com/neovim/nvim-lspconfig" },
        .{ .profile = .lsp, .uri = "https://github.com/nvim-lua/plenary.nvim" },
        // .{ .profile = .lsp, .uri = "https://github.com/jose-elias-alvarez/null-ls.nvim" },
        .{ .profile = .lsp, .uri = "/srv/playground/null-ls.nvim" },
        // .{ .profile = .lsp, .uri = "https://github.com/haolian9/null-ls.nvim", .branch = "hal", .as = "null-ls-hal" },

        // .{ .profile = .treesitter, .uri = "https://github.com/nvim-treesitter/nvim-treesitter" },
        .{ .profile = .treesitter, .uri = "https://github.com/haolian9/nvim-treesitter", .branch = "hal", .as = "nvim-treesitter-hal" },
        // .{ .profile = .treesitter, .uri = "https://github.com/nvim-treesitter/nvim-treesitter-refactor" },
        .{ .profile = .treesitter, .uri = "https://github.com/haolian9/nvim-treesitter-refactor", .branch = "hal", .as = "nvim-treesitter-refactor-hal" },
        // .{ .profile = .treesitter, .uri = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
        .{ .profile = .treesitter, .uri = "https://github.com/haolian9/nvim-treesitter-textobjects", .branch = "hal", .as = "nvim-treesitter-textobjects-hal" },
        .{ .profile = .treesitter, .uri = "https://github.com/nvim-treesitter/playground" },

        // .{ .profile = .code, .uri = "https://github.com/ibhagwan/fzf-lua" },
        // .{ .profile = .code, .uri = "/srv/playground/fzf-lua" },
        .{ .profile = .code, .uri = "https://github.com/haolian9/fzf-lua", .branch = "hal", .as = "fzf-lua-hal" },
        .{ .profile = .code, .uri = "https://github.com/SirVer/ultisnips" },
        .{ .profile = .code, .uri = "https://github.com/skywind3000/asyncrun.vim" },
        .{ .profile = .code, .uri = "https://github.com/tpope/vim-commentary" },

        .{ .profile = .git, .uri = "https://github.com/tpope/vim-fugitive" },
        .{ .profile = .git, .uri = "https://github.com/junegunn/gv.vim" },

        .{ .profile = .wiki, .uri = "https://github.com/vimwiki/vimwiki" },
    });
    defer spec.deinit();

    // var manager = Manager{ .allocator = allocator, .spec = spec };
    // try manager.install();

    var rtp = try specs.VimRtp.fromSpec(allocator, spec);
    defer rtp.deinit();
    try rtp.dump(std.io.getStdOut().writer());
}
