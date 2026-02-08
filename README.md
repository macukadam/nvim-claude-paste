# nvim-claude-paste

Collect code references from Neovim and send them to a running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) instance in tmux.

## Features

- **Add references** from normal mode (current line), visual selection, or treesitter (enclosing function/class)
- **Oil.nvim integration** — add file refs directly from the file explorer
- **Git diff** — add all unstaged diff hunks as refs
- **LSP diagnostics** — add buffer diagnostics as refs
- **Editable preview** — review and edit the payload before sending
- **Pane picker** — auto-detects Claude Code tmux panes; picks the closest match by CWD
- **Auto-refresh** — periodically runs `:checktime` so buffers reload after Claude edits files
- **Fully configurable** keymaps (set any to `false` to disable)

## How it works

1. You accumulate code references while navigating your codebase — lines, visual selections, treesitter nodes, diff hunks, or diagnostics.
2. When ready, `<leader>as` opens an editable preview of the formatted payload.
3. Press `<C-CR>` to paste and submit (sends Enter), or `<C-s>` to paste only (lets you append more before submitting).
4. The plugin writes the text to a temp file, loads it into a tmux buffer, and pastes it into the selected Claude Code pane.
5. After sending, the auto-refresh timer starts (if enabled), periodically calling `:checktime` to pick up file changes Claude makes.

> **Tip:** For best results, enable `autoread` and add `checktime` autocmds so buffers reload on focus/buffer switch — not just on the refresh timer:
>
> ```lua
> vim.o.autoread = true
> vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
>   command = "if mode() != 'c' | checktime | endif",
>   pattern = "*",
> })
> ```

## Requirements

- Neovim 0.10+
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) — for popup/menu UI
- [tmux](https://github.com/tmux/tmux) with a running Claude Code session

### Optional

- [oil.nvim](https://github.com/stevearc/oil.nvim) — enables adding file refs from the file explorer (`<leader>aa` in an Oil buffer)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) — with parsers installed for your languages, enables `<leader>af` to capture enclosing functions/classes
- An LSP server — enables `<leader>ax` to add buffer diagnostics as refs
- git — enables `<leader>ag` to add unstaged diff hunks as refs

## Installation

### lazy.nvim

```lua
{
  "macukadam/nvim-claude-paste.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {},
}
```

## Default Keybindings

| Keymap         | Mode | Description                          | Requires           |
|----------------|------|--------------------------------------|---------------------|
| `<leader>aa`   | n    | Add ref at cursor line               |                     |
| `<leader>aa`   | v    | Add ref from visual selection        |                     |
| `<leader>af`   | n    | Add ref for enclosing function/class | nvim-treesitter     |
| `<leader>ag`   | n    | Add all git diff hunks as refs       | git                 |
| `<leader>ax`   | n    | Add buffer diagnostics as refs       | LSP                 |
| `<leader>al`   | n    | List refs (popup)                    | nui.nvim            |
| `<leader>as`   | n    | Send refs to Claude (editable)       | nui.nvim, tmux      |
| `<leader>ad`   | n    | Clear all refs                       |                     |
| `<leader>ar`   | n    | Toggle auto-refresh timer            |                     |

### Ref list popup keys

| Key     | Action                  |
|---------|-------------------------|
| `dd`    | Delete ref under cursor |
| `Enter` | Jump to ref location    |
| `q`     | Close popup             |

### Send preview popup keys

| Key      | Action                            |
|----------|-----------------------------------|
| `<CR>`   | Paste and submit (sends Enter)    |
| `<C-s>`  | Paste only (no Enter)             |
| `q`      | Cancel                            |

## Configuration

All options with their defaults:

```lua
require("nvim-claude-paste").setup({
  keymaps = {
    add_ref = "<leader>aa",            -- set to false to disable
    add_ref_visual = "<leader>aa",
    add_ref_treesitter = "<leader>af",
    add_git_diff = "<leader>ag",
    add_diagnostics = "<leader>ax",
    list_refs = "<leader>al",
    send_refs = "<leader>as",
    clear_refs = "<leader>ad",
    toggle_auto_refresh = "<leader>ar",
  },
  auto_refresh = {
    enabled = true,          -- auto-start refresh timer on send
    interval_ms = 2000,      -- checktime interval in milliseconds
  },
})
```

### Disabling specific keymaps

Set any keymap to `false` to prevent it from being registered:

```lua
require("nvim-claude-paste").setup({
  keymaps = {
    add_ref_treesitter = false,  -- don't bind <leader>af
    toggle_auto_refresh = false, -- don't bind <leader>ar
  },
})
```

## Commands

| Command              | Description                        |
|----------------------|------------------------------------|
| `:ClaudeRefs`        | List accumulated refs              |
| `:ClaudeSend`        | Send refs to Claude                |
| `:ClaudeClear`       | Clear all refs                     |
| `:ClaudeTreesitter`  | Add enclosing function/class ref   |
| `:ClaudeDiff`        | Add git diff hunks as refs         |
| `:ClaudeDiagnostics` | Add buffer diagnostics as refs     |
| `:ClaudeWatch`       | Toggle auto-refresh timer          |

## License

MIT
