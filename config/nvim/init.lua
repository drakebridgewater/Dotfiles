-- Neovim entry point. Symlinked to ~/.config/nvim by install/symlinks.sh.
-- Modules live in lua/config/ (options, keymaps) and lua/plugins/ (lazy.nvim specs).

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Python provider venv created by install/linux-rhel8.sh (per-host, not in repo)
local nvim_venv_python = vim.fn.expand('~/.neovim_env/nvim-venv/bin/python')
if vim.fn.executable(nvim_venv_python) == 1 then
  vim.g.python3_host_prog = nvim_venv_python
end

require('config.options')
require('config.keymaps')
require('config.autocmds')
require('config.commands')
require('config.lazy')
