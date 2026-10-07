local autocmd = vim.api.nvim_create_autocmd
local group = vim.api.nvim_create_augroup('UserConfigGroup', { clear = true })

autocmd('FileType', {
  group = group,
  pattern = { 'html', 'yaml', 'lua' },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.expandtab = true
  end,
})

autocmd('FileType', {
  group = group,
  pattern = 'python',
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.expandtab = true
  end,
})

-- Trailing whitespace is significant in markdown line breaks and patch files
local keep_whitespace = { markdown = true, diff = true, gitcommit = true }

autocmd('BufWritePre', {
  group = group,
  callback = function(ev)
    if keep_whitespace[vim.bo[ev.buf].filetype] or not vim.bo[ev.buf].modifiable then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

autocmd('LspAttach', {
  group = group,
  callback = function(ev)
    local function bmap(keys, func, desc)
      vim.keymap.set('n', keys, func, { buffer = ev.buf, desc = 'LSP: ' .. desc })
    end
    bmap('gd', vim.lsp.buf.definition, 'Go to Definition')
    bmap('gr', vim.lsp.buf.references, 'Go to References')
    bmap('K', vim.lsp.buf.hover, 'Hover Documentation')
    bmap('<leader>ca', vim.lsp.buf.code_action, 'Code Action')
    bmap('<leader>rn', vim.lsp.buf.rename, 'Rename Symbol')
  end,
})
