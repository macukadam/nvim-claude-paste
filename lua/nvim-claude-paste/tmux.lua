local M = {}

local function capture_pane_preview(pane_id)
  local handle = io.popen(string.format("tmux capture-pane -t %s -p 2>/dev/null", pane_id))
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()

  -- Find the last non-empty line as a preview of current activity
  local last_line = nil
  for line in result:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      last_line = trimmed
    end
  end
  return last_line
end

function M.get_claude_panes()
  local handle = io.popen("tmux list-panes -a -F '#{pane_id}\t#{pane_current_command}\t#{pane_current_path}\t#{session_name}\t#{window_index}\t#{pane_index}' 2>/dev/null")
  if not handle then return {} end
  local result = handle:read("*a")
  handle:close()

  local panes = {}
  for line in result:gmatch("[^\r\n]+") do
    local pane_id, cmd, path, session, win_idx, pane_idx = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
    if cmd == "claude" then
      local dir_name = vim.fn.fnamemodify(path, ":t")
      local preview = capture_pane_preview(pane_id)
      -- Truncate preview to keep menu readable
      if preview and #preview > 60 then
        preview = preview:sub(1, 57) .. "..."
      end
      table.insert(panes, {
        id = pane_id,
        path = path,
        label = dir_name,
        session = session,
        window_index = win_idx,
        pane_index = pane_idx,
        preview = preview,
      })
    end
  end
  return panes
end

function M.send_to_pane(pane_id, text, submit)
  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if not f then
    vim.notify("Failed to create temp file", vim.log.levels.ERROR)
    return
  end
  f:write(text)
  f:close()

  local cmd = string.format("tmux load-buffer %s && tmux paste-buffer -t %s", vim.fn.shellescape(tmpfile), vim.fn.shellescape(pane_id))
  vim.fn.system(cmd)
  os.remove(tmpfile)
  if submit then
    vim.fn.system(string.format("sleep 0.2 && tmux send-keys -t %s Enter", vim.fn.shellescape(pane_id)))
  end
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to send to tmux pane (it may have been closed)", vim.log.levels.ERROR)
  end
end

function M.start_claude(opts)
  opts = opts or {}
  local cwd = vim.fn.getcwd()

  local function launch(dangerous)
    local cmd = "claude"
    if dangerous then
      cmd = "claude --dangerously-skip-permissions"
    end
    vim.fn.system(string.format("tmux split-window -d -h -c %s %s", vim.fn.shellescape(cwd), cmd))
    if vim.v.shell_error ~= 0 then
      vim.notify("Failed to start Claude (are you in tmux?)", vim.log.levels.ERROR)
    else
      vim.notify("Claude is starting. Retry in a few seconds.", vim.log.levels.INFO)
    end
  end

  if opts.dangerous then
    vim.ui.select({ "Yes, start with --dangerously-skip-permissions", "Cancel" }, {
      prompt = "WARNING: This skips all permission prompts. Claude will execute commands without confirmation. Continue?",
    }, function(choice)
      if choice and choice:match("^Yes") then
        launch(true)
      end
    end)
  else
    launch(false)
  end
end

function M.ensure_claude_running()
  local panes = M.get_claude_panes()
  if #panes > 0 then return end
  vim.ui.select({
    "Start Claude Code",
    "Start Claude Code (--dangerously-skip-permissions)",
    "Cancel",
  }, {
    prompt = "No Claude instances found in tmux",
  }, function(choice)
    if choice == "Start Claude Code" then
      M.start_claude()
    elseif choice and choice:match("dangerously") then
      M.start_claude({ dangerous = true })
    end
  end)
end

function M.pick_pane(callback)
  local panes = M.get_claude_panes()
  if #panes == 0 then
    M.ensure_claude_running()
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
  local max_width = 30
  for _, pane in ipairs(panes) do
    -- Format: [session:window.pane] dir_name — preview
    local location = string.format("[%s:%s.%s]", pane.session, pane.window_index, pane.pane_index)
    local line = location .. " " .. pane.label
    if pane.preview then
      line = line .. " — " .. pane.preview
    end
    if #line > max_width then max_width = #line end
    table.insert(items, Menu.item(line, { pane = pane }))
  end

  local menu = Menu({
    position = "50%",
    size = { width = math.min(max_width + 6, 90), height = math.min(#panes, 10) },
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
