call plug#begin(stdpath('data') . '/plugged')

Plug 'lewis6991/impatient.nvim'

if v:lua.profiles.has('base')
    Plug 'tpope/vim-repeat'
    Plug 'alvarosevilla95/luatab.nvim'
    Plug 'phaazon/hop.nvim'
endif

if v:lua.profiles.has('lsp')
    Plug 'neovim/nvim-lspconfig'

    " goodies: plenary.path
    " optionally required by: null-ls
    Plug 'nvim-lua/plenary.nvim'

    "Plug 'jose-elias-alvarez/null-ls.nvim'
    "Plug 'haolian9/null-ls.nvim', {'branch': 'hal', 'as': 'null-ls-hal'}
    Plug '/srv/playground/null-ls.nvim'
endif

if v:lua.profiles.has('treesitter')
    Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
    "Plug 'haolian9/nvim-treesitter', {'do': ':TSUpdate', 'branch': 'hal', 'as': 'nvim-treesitter-hal'}

    "Plug 'nvim-treesitter/nvim-treesitter-refactor'
    Plug 'haolian9/nvim-treesitter-refactor', {'branch': 'hal', 'as': 'nvim-treesitter-refactor-hal'}

    "Plug 'nvim-treesitter/nvim-treesitter-textobjects'
    Plug 'haolian9/nvim-treesitter-textobjects', {'branch': 'hal', 'as': 'nvim-treesitter-textobjects-hal'}

    "Plug 'nvim-treesitter/playground'
endif

if v:lua.profiles.has('code')
    Plug 'tpope/vim-surround'
    Plug 'junegunn/vim-easy-align'
    Plug 'michaeljsmith/vim-indent-object'

    "Plug 'ibhagwan/fzf-lua', {'branch': 'main'}
    "Plug 'haolian9/fzf-lua', {'branch': 'hal', 'as': 'fzf-lua-hal'}
    Plug '/srv/playground/fzf-lua'

    Plug 'SirVer/ultisnips'
    Plug 'majutsushi/tagbar'
    Plug 'mhartington/formatter.nvim'
    Plug 'skywind3000/asyncrun.vim'
    Plug 'tpope/vim-commentary'
endif

if v:lua.profiles.has('git')
    Plug 'tpope/vim-fugitive'
    Plug 'junegunn/gv.vim'
endif

if v:lua.profiles.has('wiki')
    Plug 'vimwiki/vimwiki'
endif

call plug#end()
