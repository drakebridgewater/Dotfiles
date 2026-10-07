local command = vim.api.nvim_create_user_command

command('InsertTime', function()
  local timestamp = os.date('%Y-%m-%d %H:%M:%S.0 %z')
  vim.api.nvim_put({ timestamp }, 'c', true, true)
end, { desc = 'Insert current ISO timestamp' })

command('WC', function()
  local filepath = vim.fn.expand('%')
  if filepath == '' then
    vim.notify('Buffer has no file path', vim.log.levels.WARN)
    return
  end
  if vim.fn.executable('detex') == 0 then
    vim.notify('detex not found', vim.log.levels.ERROR)
    return
  end
  local cmd = string.format("detex %s | wc -w | tr -d '[:space:]'", vim.fn.shellescape(filepath))
  vim.notify(vim.fn.system(cmd) .. ' words', vim.log.levels.INFO)
end, { desc = 'Count words with detex' })

-- md5sum on Linux, md5 on macOS
command('Md5', function(opts)
  local tool = vim.fn.executable('md5sum') == 1 and 'md5sum' or 'md5'
  local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
  local out = vim.fn.system(tool, table.concat(lines, '\n'))
  vim.notify('MD5: ' .. vim.split(vim.trim(out), '%s+')[1], vim.log.levels.INFO)
end, { range = true, desc = 'Generate MD5 of lines' })
