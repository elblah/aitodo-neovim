# AITODO Neovim Integration

A simple but powerful Neovim integration that allows you to mark code sections with `AITODO:` comments and have AI fill them in with a single keypress.

**Uses [aicoder v3](https://github.com/elblah/v3)** as the AI backend.

## Why This Exists

The traditional AI coding workflow is clunky:
1. Switch to a separate AI tool/chat window
2. Copy your code context
3. Type your request
4. Wait for response
5. Copy the response back
6. Paste and integrate

This integration eliminates all that friction. You write `AITODO:` comments directly in your code, describing what you want, and press one key to have AI replace those comments with actual working code.

## How It Works

The system has three components:

### 1. Insert `AITODO:` Marker (Ctrl+a)

When you're in insert mode, pressing `Ctrl+a` inserts an `AITODO:` comment marker with the correct comment prefix for your file type:

- Python/Shell/Ruby: `# AITODO: `
- JavaScript/TypeScript/Java/C/C++/Rust/Go/Swift: `// AITODO: `
- Lua: `-- AITODO: `

You then type what you want AI to do after the marker. Example:
```javascript
// AITODO: create a function that validates email addresses using regex
```

### 2. Process AITODOs (leader+a)

In normal mode, pressing `<leader>a`:
1. Saves your file
2. Locks the buffer (prevents editing while processing)
3. Calls `~/bin/aicoder-nvim` with your file path
4. Waits for completion
5. Reloads the file with AI-generated code replacing AITODO markers

### 3. Backend Scripts

Two shell scripts handle the AI processing:

**`aicoder-nvim`**: Wrapper that sets environment variables and calls aicoder:
- Sets API credentials (model, URL, key)
- Configures available tools (read_file, write_file, list_directory)
- Sends a prompt to aicoder: "read the file and do whatever is asked in the AITODO sections"

**`aicoder-start`**: Your aicoder launcher script (paths may vary)
- This is where you configure which aicoder version to use
- Handles sandboxing, worktrees, and other aicoder-specific settings

The aicoder used in this example is available at https://github.com/elblah/v3

## Adapting to Your Config

### Step 1: Copy the Neovim Lua Code

Add these snippets to your `init.lua`:

```lua
-- Insert AITODO marker with language-specific comment prefix
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

-- Process AITODOs with aicoder
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
```

### Step 2: Create `~/bin/aicoder-nvim`

Create this script with your AI provider credentials:

```bash
#!/bin/bash

# Configure your AI provider
export API_MODEL=gpt-4o
export API_BASE_URL=https://api.openai.com/v1
export API_KEY="your-api-key-here"

# Enable automatic mode (less confirmation prompts)
export YOLO_MODE=1
export MAX_RETRIES=99999

# Allow only necessary tools for safety
export TOOLS_ALLOW="read_file,write_file,list_directory"
export PLUGINS_ALLOW="skills,empty_retry"

# Large context for big files
export CONTEXT_SIZE=200000

user_prompt="read the file '$1' and do whatever is asked in the AITODO sections... make sure to do all you can to comply to whatever is asked... don't leave AITODO lines unless you could not do what was asked"

echo "$user_prompt" | timeout -k 5s 3m aicoder-start
```

Make it executable:
```bash
chmod +x ~/bin/aicoder-nvim
```

### Step 3: Ensure `aicoder-start` is Available

The `aicoder-nvim` script calls `aicoder-start`. Make sure:
1. `aicoder-start` is in your PATH, OR
2. Modify the last line of `aicoder-nvim` to use the full path to your aicoder launcher

If you're using the reference implementation, `aicoder-start` might be a complex script with worktree support, sandboxing, etc. You can simplify it if you don't need those features:

```bash
#!/bin/bash
# Simple aicoder-start wrapper
python ~/path/to/aicoder/main.py "$@"
```

### Step 4: Customize (Optional)

**Change keybindings:**
- `<C-a>` for insert → change the first keymap's lhs
- `<leader>a` for process → change the second keymap's lhs

**Add more file types:**
Add entries to the `cmd_text` table for languages you use:
```lua
zig = "// AITODO: ",
kotlin = "// AITODO: ",
```

**Adjust timeout:**
In `aicoder-nvim`, change `3m` (3 minutes) if you need longer/shorter processing time.

## Example Workflow

1. Open a file in Neovim
2. Go to where you want AI to write code
3. Press `Ctrl+a` in insert mode → inserts `// AITODO: `
4. Type your request: `create a function that sorts an array of objects by a given property name`
5. Press `<leader>a` in normal mode
6. Wait a few seconds
7. File reloads with AI-generated code replacing the AITODO comment

## Notes

- The file must be saved on disk (not an unsaved buffer)
- The buffer is locked during processing to prevent conflicts
- On error, the output buffer opens in a split so you can debug
- Multiple AITODOs in one file are all processed in a single pass
- The timeout prevents hanging; increase if you have slow AI responses

## License

See LICENSE file for details.
