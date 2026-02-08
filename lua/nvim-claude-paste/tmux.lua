local M = {}

function M.get_claude_panes()
  local handle = io.popen("tmux list-panes -a -F '#{pane_id} #{pane_current_command} #{pane_current_path}' 2>/dev/null")
  if not handle then return {} end
  local result = handle:read("*a")
  handle:close()

  local panes = {}
  for line in result:gmatch("[^\r\n]+") do
    local pane_id, cmd, path = line:match("^(%S+)%s+(%S+)%s+(.+)$")
    if cmd == "claude" then
      table.insert(panes, { id = pane_id, path = path, label = vim.fn.fnamemodify(path, ":t") })
    end
  end
  return panes
end

function M.send_to_pane(pane_id, text, submit)
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  if not f then
    vim.notify("Failed to create temp file", vim.log.levels.ERROR)
    return
  end
  f:write(text)
  f:close()

  local cmd = string.format("tmux load-buffer %s && tmux paste-buffer -t %s", tmpfile, pane_id)
  if submit then
    cmd = cmd .. string.format(" && tmux send-keys -t %s Enter", pane_id)
  end
  vim.fn.system(cmd)
  os.remove(tmpfile)
end

function M.pick_pane(callback)
  local panes = M.get_claude_panes()
  if #panes == 0 then
    vim.notify("No Claude instances found in tmux", vim.log.levels.ERROR)
    return
  end

  if #panes == 1 then
    callback(panes[1])
    return
  end

  -- Sort: prefer pane whose CWD matches nvim's git root
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1] or ""
  table.sort(panes, function(a, b)
    local a_match = a.path == git_root
    local b_match = b.path == git_root
    if a_match ~= b_match then return a_match end
    return a.label < b.label
  end)

  local ok, Menu = pcall(require, "nui.menu")
  if not ok then
    vim.notify("nui.nvim is required for pane picker UI", vim.log.levels.ERROR)
    return
  end

  local items = {}
  for _, pane in ipairs(panes) do
    table.insert(items, Menu.item(pane.label .. " (" .. pane.id .. ")", { pane = pane }))
  end

  local menu = Menu({
    position = "50%",
    size = { width = 50, height = math.min(#panes, 10) },
    border = {
      style = "rounded",
      text = { top = " Send to Claude ", top_align = "center" },
    },
  }, {
    lines = items,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "<C-c>" },
      submit = { "<CR>" },
    },
    on_submit = function(item)
      callback(item.pane)
    end,
  })

  menu:mount()
end

return M
