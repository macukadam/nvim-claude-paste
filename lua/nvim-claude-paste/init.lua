local config = require("nvim-claude-paste.config")
local refs = require("nvim-claude-paste.refs")
local tmux = require("nvim-claude-paste.tmux")
local ui = require("nvim-claude-paste.ui")
local refresh = require("nvim-claude-paste.refresh")

local M = {}

-- Re-export public API
M.add_ref = refs.add_ref
M.add_ref_treesitter = refs.add_ref_treesitter
M.add_git_diff_refs = refs.add_git_diff_refs
M.add_diagnostic_refs = refs.add_diagnostic_refs
M.clear_refs = function()
  local count = refs.clear()
  vim.notify("Cleared " .. count .. " reference" .. (count == 1 and "" or "s"), vim.log.levels.INFO)
end

M.list_refs = ui.list_refs
M.send_refs = ui.send_refs

M.start_auto_refresh = refresh.start
M.stop_auto_refresh = refresh.stop
M.toggle_auto_refresh = refresh.toggle

M.get_claude_panes = tmux.get_claude_panes
M.start_claude = function() tmux.start_claude() end
M.start_claude_dangerous = function() tmux.start_claude({ dangerous = true }) end

function M.setup(opts)
  config.setup(opts)

  local cfg = config.get()

  -- Commands
  vim.api.nvim_create_user_command("ClaudeRefs", M.list_refs, {})
  vim.api.nvim_create_user_command("ClaudeSend", M.send_refs, {})
  vim.api.nvim_create_user_command("ClaudeClear", M.clear_refs, {})
  vim.api.nvim_create_user_command("ClaudeTreesitter", M.add_ref_treesitter, {})
  vim.api.nvim_create_user_command("ClaudeDiff", M.add_git_diff_refs, {})
  vim.api.nvim_create_user_command("ClaudeDiagnostics", M.add_diagnostic_refs, {})
  vim.api.nvim_create_user_command("ClaudeWatch", function() M.toggle_auto_refresh() end, {})
  vim.api.nvim_create_user_command("ClaudeStart", M.start_claude, {})
  vim.api.nvim_create_user_command("ClaudeStartDangerous", M.start_claude_dangerous, {})

  -- Keymaps
  local km = cfg.keymaps
  local map_opts = { noremap = true, silent = true }

  if km.add_ref then
    vim.keymap.set("n", km.add_ref, function() M.add_ref(false) end, vim.tbl_extend("force", map_opts, { desc = "Add Claude ref" }))
  end
  if km.add_ref_visual then
    vim.keymap.set("v", km.add_ref_visual, function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
      M.add_ref(true)
    end, vim.tbl_extend("force", map_opts, { desc = "Add Claude ref (visual)" }))
  end
  if km.add_ref_treesitter then
    vim.keymap.set("n", km.add_ref_treesitter, M.add_ref_treesitter, vim.tbl_extend("force", map_opts, { desc = "Add Claude ref (treesitter)" }))
  end
  if km.add_git_diff then
    vim.keymap.set("n", km.add_git_diff, M.add_git_diff_refs, vim.tbl_extend("force", map_opts, { desc = "Add git diff as Claude refs" }))
  end
  if km.add_diagnostics then
    vim.keymap.set("n", km.add_diagnostics, M.add_diagnostic_refs, vim.tbl_extend("force", map_opts, { desc = "Add diagnostics as Claude refs" }))
  end
  if km.list_refs then
    vim.keymap.set("n", km.list_refs, M.list_refs, vim.tbl_extend("force", map_opts, { desc = "List Claude refs" }))
  end
  if km.send_refs then
    vim.keymap.set("n", km.send_refs, M.send_refs, vim.tbl_extend("force", map_opts, { desc = "Send Claude refs" }))
  end
  if km.clear_refs then
    vim.keymap.set("n", km.clear_refs, M.clear_refs, vim.tbl_extend("force", map_opts, { desc = "Clear Claude refs" }))
  end
  if km.toggle_auto_refresh then
    vim.keymap.set("n", km.toggle_auto_refresh, function() M.toggle_auto_refresh() end, vim.tbl_extend("force", map_opts, { desc = "Toggle Claude auto-refresh" }))
  end
  if km.start_claude then
    vim.keymap.set("n", km.start_claude, M.start_claude, vim.tbl_extend("force", map_opts, { desc = "Start Claude Code" }))
  end
  if km.start_claude_dangerous then
    vim.keymap.set("n", km.start_claude_dangerous, M.start_claude_dangerous, vim.tbl_extend("force", map_opts, { desc = "Start Claude Code (dangerous)" }))
  end
end

return M
