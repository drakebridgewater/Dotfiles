-- Requires Neovim 0.11+ (vim.lsp.config / vim.lsp.enable)
return {
  {
    'neovim/nvim-lspconfig', -- supplies the default server definitions
    dependencies = { 'mason-org/mason.nvim', 'saghen/blink.cmp' },
    config = function()
      -- Adds mason's bin dir to $PATH; nothing is auto-installed (hosts may be offline). Use :Mason.
      require('mason').setup()

      vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
      vim.lsp.config('lua_ls', {
        settings = { Lua = { diagnostics = { globals = { 'vim' } } } },
      })

      -- Only enable servers whose binary exists on this host
      local servers = { clangd = 'clangd', pyright = 'pyright-langserver', lua_ls = 'lua-language-server' }
      for name, bin in pairs(servers) do
        if vim.fn.executable(bin) == 1 then
          vim.lsp.enable(name)
        end
      end
    end,
  },
}
