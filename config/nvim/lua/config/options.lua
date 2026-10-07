local opt = vim.opt

-- Behavior & History
opt.hidden = true
opt.history = 1000
opt.scrolloff = 3
opt.mouse = "a"
opt.clipboard = "unnamedplus" -- Sync with system clipboard

-- Search
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Appearance
opt.termguicolors = true
opt.laststatus = 2
opt.number = true             -- Enabled by default (modern standard)
opt.relativenumber = true     -- Fast vertical jumps

-- Shell & Formats
opt.shell = "bash"
opt.completeopt = { "menu", "menuone", "noselect" }

-- Leader Key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.undofile = true
opt.signcolumn = 'yes'
opt.splitright = true
opt.splitbelow = true
opt.updatetime = 250
opt.expandtab = true

opt.shiftwidth = 4
opt.tabstop = 4

-- Match ~/.vimrc per-filetype indentation
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'html', 'yaml', 'lua' },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
  end,
})


