-- Bootstrap lazy.nvim (installed to stdpath('data'), not tracked in the repo)
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', 'https://github.com/folke/lazy.nvim.git', lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { 'Failed to clone lazy.nvim:\n' .. out, 'ErrorMsg' } }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

-- lockfile lives in the repo so plugin versions are identical across machines
require('lazy').setup('plugins', {
  lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
  change_detection = { notify = false },
})
