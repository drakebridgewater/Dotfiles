local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('n', '<C-h>', '<C-w>h')
map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k')
map('n', '<C-l>', '<C-w>l')

-- Needs `stty -ixon` in the shell, otherwise the terminal swallows <C-s>
map({ 'n', 'i' }, '<C-s>', '<cmd>silent! update<cr><esc>', { desc = 'Save buffer' })

map('c', '%%', "<C-R>=expand('%:h').'/'<cr>", { desc = 'Expand current buffer dir' })
map('n', '<leader>e', ":edit <C-R>=expand('%:h').'/'<cr>", { desc = 'Edit in current dir' })
map('n', '<leader>v', ":view <C-R>=expand('%:h').'/'<cr>", { desc = 'View in current dir' })

map('n', '<F10>', '<cmd>WC<cr>', { desc = 'LaTeX word count' })
