local M = {}

M.defaults = {
  keymaps = {
    add_ref = "<leader>ca",
    add_ref_visual = "<leader>ca",
    add_ref_treesitter = "<leader>cf",
    add_git_diff = "<leader>cg",
    add_diagnostics = "<leader>cx",
    list_refs = "<leader>cl",
    send_refs = "<leader>cs",
    clear_refs = "<leader>cd",
    toggle_auto_refresh = "<leader>cr",
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
