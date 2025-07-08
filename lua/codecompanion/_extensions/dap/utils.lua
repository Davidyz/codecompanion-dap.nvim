local M = {}

---@generic T table|string
---@param data T
---@return T
function M.convert_path(data)
  if type(data) == "string" then
    data = vim.fs.normalize(data)
    local stat = vim.uv.fs_stat(data)
    if stat then
      data = vim.fs.relpath(vim.uv.cwd() or ".", data) or data
    end
  elseif type(data) == "table" then
    for k, v in pairs(data) do
      if
        (type(v) == "string" and type(k) == "string" and k:lower():find("path"))
        or type(v) == "table"
      then
        data[k] = M.convert_path(v)
      end
    end
  end
  return data
end

return M
