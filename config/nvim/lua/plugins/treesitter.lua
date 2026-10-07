return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master', -- the default branch dropped the `configs` module
    build = ':TSUpdate',
    config = function()
      -- Parsers are compiled locally, so skip installs on hosts without a C compiler
      local can_compile = vim.fn.executable('cc') == 1 or vim.fn.executable('gcc') == 1
      require('nvim-treesitter.configs').setup({
        ensure_installed = can_compile and { 'c', 'cpp', 'python', 'html', 'yaml', 'lua', 'bash', 'markdown' } or {},
        auto_install = can_compile,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}
