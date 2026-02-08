local M = {}

M.defaults = {
  keymaps = {
    add_ref = "<leader>aa",
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
    enabled = true,
    interval_ms = 2000,
  },
}

local config = vim.deepcopy(M.defaults)

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.get()
  return config
end

return M
