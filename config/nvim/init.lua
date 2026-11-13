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

-- Plugins need 0.11+ (vim.uv, vim.lsp.config). Older system nvims (RHEL8 ships 0.8)
-- still get options/keymaps; the shell `nvim` function picks the newest binary on $PATH.
if vim.fn.has('nvim-0.11') == 0 then
  local v = vim.version()
  vim.api.nvim_echo({ {
    string.format('nvim %d.%d.%d is too old for plugins (need 0.11+); running without them. Binary: %s',
      v.major, v.minor, v.patch, vim.v.progpath),
    'WarningMsg',
  } }, true, {})
  return
end

require('config.lazy')
