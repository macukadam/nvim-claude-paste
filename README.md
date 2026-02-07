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
2. When ready, `<leader>cs` opens an editable preview of the formatted payload.
3. On confirm (`<C-s>`), the plugin writes the text to a temp file, loads it into a tmux buffer, and pastes it into the selected Claude Code pane.
4. If `auto_submit` is enabled (default), an `Enter` keystroke is sent after the paste so Claude starts processing immediately.
5. After sending, the auto-refresh timer starts (if enabled), periodically calling `:checktime` to pick up file changes Claude makes.

## Requirements

- Neovim 0.10+
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) — for popup/menu UI
- [tmux](https://github.com/tmux/tmux) with a running Claude Code session

### Optional

- [oil.nvim](https://github.com/stevearc/oil.nvim) — enables adding file refs from the file explorer (`<leader>ca` in an Oil buffer)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) — with parsers installed for your languages, enables `<leader>cf` to capture enclosing functions/classes
- An LSP server — enables `<leader>cx` to add buffer diagnostics as refs
- git — enables `<leader>cg` to add unstaged diff hunks as refs

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
| `<leader>ca`   | n    | Add ref at cursor line               |                     |
| `<leader>ca`   | v    | Add ref from visual selection        |                     |
| `<leader>cf`   | n    | Add ref for enclosing function/class | nvim-treesitter     |
| `<leader>cg`   | n    | Add all git diff hunks as refs       | git                 |
| `<leader>cx`   | n    | Add buffer diagnostics as refs       | LSP                 |
| `<leader>cl`   | n    | List refs (popup)                    | nui.nvim            |
| `<leader>cs`   | n    | Send refs to Claude (editable)       | nui.nvim, tmux      |
| `<leader>cd`   | n    | Clear all refs                       |                     |
| `<leader>cr`   | n    | Toggle auto-refresh timer            |                     |

### Ref list popup keys

| Key     | Action                  |
|---------|-------------------------|
| `dd`    | Delete ref under cursor |
| `Enter` | Jump to ref location    |
| `q`     | Close popup             |

### Send preview popup keys

| Key      | Action       |
|----------|--------------|
| `<C-s>`  | Send to pane |
| `q`      | Cancel       |

## Configuration

All options with their defaults:

```lua
require("nvim-claude-paste").setup({
  keymaps = {
    add_ref = "<leader>ca",            -- set to false to disable
    add_ref_visual = "<leader>ca",
    add_ref_treesitter = "<leader>cf",
    add_git_diff = "<leader>cg",
    add_diagnostics = "<leader>cx",
    list_refs = "<leader>cl",
    send_refs = "<leader>cs",
    clear_refs = "<leader>cd",
    toggle_auto_refresh = "<leader>cr",
  },
  auto_submit = true,       -- send Enter after pasting to tmux
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
    add_ref_treesitter = false,  -- don't bind <leader>cf
    toggle_auto_refresh = false, -- don't bind <leader>cr
  },
})
```

### Disabling auto-submit

By default the plugin sends `Enter` after pasting into the tmux pane so Claude starts processing immediately. To paste without submitting:

```lua
require("nvim-claude-paste").setup({
  auto_submit = false,
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
