local config = require("nvim-claude-paste.config")

local M = {}

local timer = nil

function M.is_running()
  return timer ~= nil
end

function M.start(interval_ms)
  if timer then return end
  local cfg = config.get()
  interval_ms = interval_ms or cfg.auto_refresh.interval_ms
  timer = vim.uv.new_timer()
  timer:start(0, interval_ms, vim.schedule_wrap(function()
    if vim.fn.getcmdwintype() == "" and vim.fn.mode() == "n" then
      vim.cmd("silent! checktime")
    end
  end))
  vim.notify("Auto-refresh on (" .. interval_ms .. "ms)", vim.log.levels.INFO)
end

function M.stop()
  if not timer then
    vim.notify("Auto-refresh already off", vim.log.levels.WARN)
    return
  end
  timer:stop()
  timer:close()
  timer = nil
  vim.notify("Auto-refresh off", vim.log.levels.INFO)
end

function M.toggle(interval_ms)
  if timer then
    M.stop()
  else
    M.start(interval_ms)
  end
end

return M
