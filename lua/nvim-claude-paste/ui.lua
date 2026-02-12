local refs_mod = require("nvim-claude-paste.refs")
local tmux = require("nvim-claude-paste.tmux")
local config = require("nvim-claude-paste.config")
local refresh = require("nvim-claude-paste.refresh")

local M = {}

function M.list_refs()
  local refs = refs_mod.get()
  if #refs == 0 then
    vim.notify("No refs accumulated", vim.log.levels.WARN)
    return
  end

  local ok_popup, Popup = pcall(require, "nui.popup")
  if not ok_popup then
    vim.notify("nui.nvim is required for list_refs UI", vim.log.levels.ERROR)
    return
  end
  local ok_event, autocmd = pcall(require, "nui.utils.autocmd")
  if not ok_event then
    vim.notify("nui.nvim is required for list_refs UI", vim.log.levels.ERROR)
    return
  end
  local event = autocmd.event

  local lines = {}
  for i, ref in ipairs(refs) do
    table.insert(lines, refs_mod.format_ref_short(i, ref))
  end

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = { top = " Claude Refs (" .. #refs .. ") ", top_align = "center" },
    },
    position = "50%",
    size = { width = "80%", height = math.min(#refs + 2, 20) },
  })

  popup:mount()
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  popup:on(event.BufLeave, function() popup:unmount() end)

  popup:map("n", "q", function() popup:unmount() end)
  popup:map("n", "<Esc>", function() popup:unmount() end)

  -- dd to delete the ref under cursor
  popup:map("n", "dd", function()
    local row = vim.fn.line(".")
    if row >= 1 and row <= #refs then
      refs_mod.remove(row)
      vim.bo[popup.bufnr].modifiable = true
      if refs_mod.count() == 0 then
        popup:unmount()
        vim.notify("All refs cleared", vim.log.levels.INFO)
      else
        local new_lines = {}
        local current_refs = refs_mod.get()
        for i, ref in ipairs(current_refs) do
          table.insert(new_lines, refs_mod.format_ref_short(i, ref))
        end
        vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, new_lines)
        vim.bo[popup.bufnr].modifiable = false
        popup.border:set_text("top", " Claude Refs (" .. refs_mod.count() .. ") ", "center")
      end
    end
  end)

  -- Enter to jump to location
  popup:map("n", "<CR>", function()
    local row = vim.fn.line(".")
    if row >= 1 and row <= #refs then
      local ref = refs[row]
      popup:unmount()
      vim.cmd("edit " .. vim.fn.fnameescape(ref.file))
      if ref.start_line > 0 then
        vim.api.nvim_win_set_cursor(0, { ref.start_line, 0 })
      end
    end
  end)
end

function M.send_refs()
  local refs = refs_mod.get()
  if #refs == 0 then
    vim.notify("No refs to send", vim.log.levels.WARN)
    return
  end

  local ok_popup, Popup = pcall(require, "nui.popup")
  if not ok_popup then
    vim.notify("nui.nvim is required for send_refs UI", vim.log.levels.ERROR)
    return
  end

  -- Pick pane first so we can make paths relative to its CWD
  tmux.pick_pane(function(pane)
    local text = refs_mod.format_refs_for_send(pane.path)
    local ref_count = #refs

    local popup = Popup({
      enter = true,
      focusable = true,
      border = {
        style = "rounded",
        text = {
          top = " Send to [" .. pane.session .. ":" .. pane.window_index .. "." .. pane.pane_index .. "] " .. pane.label .. " (<CR> submit, <C-s> paste, q cancel) ",
          top_align = "center",
        },
      },
      position = "50%",
      size = { width = "80%", height = "60%" },
    })

    popup:mount()

    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
    vim.bo[popup.bufnr].filetype = "markdown"
    vim.bo[popup.bufnr].modifiable = true

    local function send(submit)
      local buf_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
      local edited_text = table.concat(buf_lines, "\n")
      popup:unmount()
      tmux.send_to_pane(pane.id, edited_text, submit)
      refs_mod.clear()
      local cfg = config.get()
      if cfg.auto_refresh.enabled and not refresh.is_running() then
        refresh.start()
      end
      vim.notify("Sent " .. ref_count .. " refs to [" .. pane.session .. ":" .. pane.window_index .. "." .. pane.pane_index .. "] " .. pane.label .. " (cleared)", vim.log.levels.INFO)
    end

    -- Set mappings after filetype to override any ftplugin <CR> mappings
    vim.schedule(function()
      popup:map("n", "<CR>", function() send(true) end)
      popup:map("n", "<C-s>", function() send(false) end)
      popup:map("n", "q", function() popup:unmount() end)
    end)
  end)
end

return M
