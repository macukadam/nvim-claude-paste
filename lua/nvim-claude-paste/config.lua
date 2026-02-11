local M = {}

M.defaults = {
  keymaps = {
    add_ref = "<leader>aa",
    add_ref_visual = "<leader>aa",
    add_ref_treesitter = "<leader>af",
    add_git_diff = "<leader>ag",
    add_git_diff_staged = "<leader>aG",
    add_git_diff_all = false,
    add_diagnostics = "<leader>ax",
    list_refs = "<leader>al",
    send_refs = "<leader>as",
    clear_refs = "<leader>ad",
    toggle_auto_refresh = "<leader>ar",
    start_claude = "<leader>ac",
    start_claude_dangerous = "<leader>a!",
  },

  auto_refresh = {
    enabled = true,
    interval_ms = 2000,
  },
}

local config = vim.deepcopy(M.defaults)

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  if type(config.auto_refresh.interval_ms) ~= "number" or config.auto_refresh.interval_ms <= 0 then
    vim.notify(
      "claude-refs: auto_refresh.interval_ms must be a positive number, using default (2000)",
      vim.log.levels.WARN
    )
    config.auto_refresh.interval_ms = M.defaults.auto_refresh.interval_ms
  end

  for key, val in pairs(config.keymaps) do
    if type(val) ~= "string" and val ~= false then
      vim.notify(
        string.format("claude-refs: keymaps.%s must be a string or false, using default", key),
        vim.log.levels.WARN
      )
      config.keymaps[key] = M.defaults.keymaps[key]
    end
  end
end

function M.get()
  return config
end

return M
