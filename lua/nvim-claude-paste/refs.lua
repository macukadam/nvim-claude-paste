local M = {}

local refs = {}

function M.get()
  return refs
end

function M.clear()
  local count = #refs
  refs = {}
  return count
end

function M.add(ref)
  table.insert(refs, ref)
  return #refs
end

function M.remove(index)
  table.remove(refs, index)
end

function M.count()
  return #refs
end

-- Add a reference (normal or visual mode)
function M.add_ref(visual)
  local file
  local ref

  -- Oil.nvim support: resolve real path from Oil buffer
  local ok, oil = pcall(require, "oil")
  if ok then
    local oil_dir = oil.get_current_dir()
    if oil_dir then
      local entry = oil.get_cursor_entry()
      if not entry then return end
      file = vim.fs.joinpath(oil_dir, entry.name)
      ref = { file = file, start_line = 0, end_line = 0 }
      M.add(ref)
      vim.notify("Added ref #" .. #refs, vim.log.levels.INFO)
      return
    end
  end

  file = vim.fn.expand("%:p")
  ref = { file = file }

  if visual then
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    ref.start_line = start_line
    ref.end_line = end_line
    ref.code = table.concat(lines, "\n")
  else
    ref.start_line = vim.fn.line(".")
    ref.end_line = ref.start_line
  end

  M.add(ref)
  vim.notify("Added ref #" .. #refs, vim.log.levels.INFO)
end

-- Add a reference for the enclosing treesitter node (function/class/method)
function M.add_ref_treesitter()
  local file = vim.fn.expand("%:p")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1

  local ts_ok, node = pcall(vim.treesitter.get_node, { pos = { row, cursor[2] } })
  if not ts_ok or not node then
    vim.notify("No treesitter node at cursor", vim.log.levels.WARN)
    return
  end

  local target_types = {
    ["function_declaration"] = true,
    ["function_definition"] = true,
    ["method_declaration"] = true,
    ["method_definition"] = true,
    ["class_declaration"] = true,
    ["class_definition"] = true,
    ["function_item"] = true,
    ["impl_item"] = true,
    ["struct_item"] = true,
    ["local_function"] = true,
    ["function_call"] = true,
    ["arrow_function"] = true,
    ["lexical_declaration"] = true,
  }

  local target = node
  while target do
    if target_types[target:type()] then break end
    target = target:parent()
  end

  if not target then
    vim.notify("No enclosing function/class found", vim.log.levels.WARN)
    return
  end

  local start_row, _, end_row, _ = target:range()
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)

  local ref = {
    file = file,
    start_line = start_row + 1,
    end_line = end_row + 1,
    code = table.concat(lines, "\n"),
  }

  M.add(ref)
  vim.notify("Added ref #" .. #refs .. " (" .. target:type() .. ")", vim.log.levels.INFO)
end

-- Add all git diff hunks as refs
function M.add_git_diff_refs()
  local diff = vim.fn.systemlist("git diff")
  if vim.v.shell_error ~= 0 or #diff == 0 then
    vim.notify("No git diff output", vim.log.levels.WARN)
    return
  end

  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1] or ""
  local current_file = nil
  local hunk_start = 0
  local hunk_lines = {}
  local added = 0

  local function flush_hunk()
    if current_file and #hunk_lines > 0 then
      M.add({
        file = git_root .. "/" .. current_file,
        start_line = hunk_start,
        end_line = hunk_start + #hunk_lines - 1,
        code = table.concat(hunk_lines, "\n"),
        comment = "git diff",
      })
      added = added + 1
    end
    hunk_lines = {}
  end

  for _, line in ipairs(diff) do
    local file = line:match("^%+%+%+ b/(.+)$")
    if file then
      flush_hunk()
      current_file = file
    end

    local new_start = line:match("^@@ .+ %+(%d+)")
    if new_start then
      flush_hunk()
      hunk_start = tonumber(new_start)
    end

    if current_file and hunk_start > 0 then
      if line:sub(1, 1) == "+" and not line:match("^%+%+%+") then
        table.insert(hunk_lines, line:sub(2))
      elseif line:sub(1, 1) == " " then
        table.insert(hunk_lines, line:sub(2))
      end
    end
  end
  flush_hunk()

  if added == 0 then
    vim.notify("No hunks found in diff", vim.log.levels.WARN)
  else
    vim.notify("Added " .. added .. " diff hunk" .. (added == 1 and "" or "s") .. " as refs", vim.log.levels.INFO)
  end
end

-- Add LSP diagnostics from current buffer as refs
function M.add_diagnostic_refs()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(bufnr)

  if #diagnostics == 0 then
    vim.notify("No diagnostics in current buffer", vim.log.levels.WARN)
    return
  end

  local file = vim.fn.expand("%:p")
  local severity_labels = { "ERROR", "WARN", "INFO", "HINT" }

  for _, d in ipairs(diagnostics) do
    local line = d.lnum + 1
    local severity = severity_labels[d.severity] or "UNKNOWN"
    M.add({
      file = file,
      start_line = line,
      end_line = line,
      comment = severity .. ": " .. d.message,
    })
  end

  vim.notify("Added " .. #diagnostics .. " diagnostic" .. (#diagnostics == 1 and "" or "s") .. " as refs", vim.log.levels.INFO)
end

-- Make filepath relative to base directory; falls back to absolute if not under base
local function relative_to(filepath, base)
  if not base or base == "" then
    return vim.fn.fnamemodify(filepath, ":~:.")
  end
  local prefix = base:gsub("/$", "") .. "/"
  if filepath:sub(1, #prefix) == prefix then
    return filepath:sub(#prefix + 1)
  end
  return filepath
end

-- Format a ref for display in the list viewer
function M.format_ref_short(i, ref, base_path)
  local rel = relative_to(ref.file, base_path)
  if ref.start_line == 0 then
    local comment_part = ref.comment and (" — " .. ref.comment) or ""
    return string.format("[%d] %s%s", i, rel, comment_part)
  end
  local loc = ref.start_line == ref.end_line
    and string.format("%s:%d", rel, ref.start_line)
    or string.format("%s:%d-%d", rel, ref.start_line, ref.end_line)
  local comment_part = ref.comment and (" — " .. ref.comment) or ""
  return string.format("[%d] %s%s", i, loc, comment_part)
end

-- Format all refs for sending to Claude
function M.format_refs_for_send(base_path)
  local parts = {}
  for _, ref in ipairs(refs) do
    local rel = relative_to(ref.file, base_path)
    local loc
    if ref.start_line == 0 then
      loc = rel
    elseif ref.start_line == ref.end_line then
      loc = string.format("%s:%d", rel, ref.start_line)
    else
      loc = string.format("%s:%d-%d", rel, ref.start_line, ref.end_line)
    end
    local comment_part = ref.comment and (" (" .. ref.comment .. ")") or ""
    local entry = loc .. comment_part
    if ref.code then
      entry = entry .. "\n" .. ref.code
    end
    table.insert(parts, entry)
  end
  return table.concat(parts, "\n\n")
end

return M
