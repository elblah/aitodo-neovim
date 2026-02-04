-- append this to your neovim init.lua

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    local cmd_text = {
      python = "# AITODO: ",
      sh = "# AITODO: ",
      ruby = "# AITODO: ",
      php = "// AITODO: ",
      javascript = "// AITODO: ",
      typescript = "// AITODO: ",
      java = "// AITODO: ",
      c = "// AITODO: ",
      cpp = "// AITODO: ",
      rust = "// AITODO: ",
      go = "// AITODO: ",
      swift = "// AITODO: ",
      lua = "-- AITODO: ",
    }
    local ft = vim.bo.filetype
    vim.keymap.set("i", "<C-a>", cmd_text[ft] or "AITODO:", { buffer = true })
  end,
})

vim.keymap.set("n", "<leader>a", function()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    print("Buffer has no file")
    return
  end

  vim.cmd("write")  -- save file

  local bufnr = vim.api.nvim_get_current_buf()
  local output_buf = vim.api.nvim_create_buf(false, true)  -- scratch buffer for output

  print("Processing... please wait...")
  vim.bo[bufnr].modifiable = false

  -- Start job asynchronously
  vim.fn.jobstart(
    { "bash", vim.env.HOME .. "/bin/aicoder-nvim", filepath },
    {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, data)
        end
      end,
      on_stderr = function(_, data)
        if data then
          vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, data)
        end
      end,
      on_exit = function(_, exit_code)
        vim.bo[bufnr].modifiable = true
        if exit_code == 0 then
          vim.schedule(function()
            vim.cmd("edit!")
            vim.cmd("redraw!")
            print("AIDONE! File processed and reloaded.")
          end)
        else
          vim.schedule(function()
            vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, { "Script error, exit code: " .. exit_code })
            vim.cmd("botright split")
            vim.api.nvim_win_set_buf(0, output_buf)
          end)
        end
      end,
    }
  )
end, { desc = "Run aicoder for AITODOs" })
