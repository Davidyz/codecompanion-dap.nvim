---@module "codecompanion"
---@module "dap"

---@class CodeCompanionDap.ScratchBufManager.InitOpts
---@field bufname_prefix string
---@field listed boolean?
---Message prefixed to the scratch buffer
---@field prefix string?

---Creates and manages scratch buffer created by DAP requests.
---These scratch buffers will contain the DAP results and monitored by Watcher.
---@class CodeCompanionDap.ScratchBufManager: CodeCompanionDap.ScratchBufManager.InitOpts
---Maps session ID to bufnr
---@field session_to_buf table<integer, integer>
local ScratchBufManager = {}

---@param opts CodeCompanionDap.ScratchBufManager.InitOpts
---@return CodeCompanionDap.ScratchBufManager
function ScratchBufManager.new(opts)
  opts = vim.tbl_deep_extend("force", {
    session_to_buf = {},
    bufname_prefix = vim.trim(opts.bufname_prefix or "dap_scratch_buf"),
    listed = false,
    ref_added = {},
    prefix = [[This is a dummy buffer for data handling.
The user WILL NOT see this buffer.
DO NOT MENTION THE PATH OR THE NAME OF THIS BUFFER TO THE USER.
ONLY USE THE INFORMATION FROM THIS BUFFER TO ASSIST YOUR TASK.
THE REMOVAL OF THIS BUFFER MEANS THAT THE RESOURCES RECORDED IN THIS BUFFER ARE NO LONGER AVAILABLE.
]],
  }, opts or {})

  opts.prefix = vim.trim(opts.prefix)

  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionDapSessionTerminated",
    callback = function(args)
      local session_id = args.data.session_id
      local bufnr = opts.session_to_buf[session_id]
      if bufnr then
        pcall(
          vim.schedule_wrap(vim.api.nvim_buf_delete),
          bufnr,
          { unload = false, force = true }
        )
      end
    end,
  })
  return setmetatable(opts, { __index = ScratchBufManager })
end

---Returns the bufname without the cwd.
---This can be used as a more readable alternative to `nvim_buf_get_name` in UI elements.
---@param session dap.Session
---@return string
function ScratchBufManager:get_readable_bufname(session)
  self:get_bufnr(session)
  return string.format("%s (session %d)", self.bufname_prefix, session.id)
end

---@param session dap.Session
---@return integer
function ScratchBufManager:get_bufnr(session)
  if self.session_to_buf[session.id] == nil then
    local bufnr = vim.api.nvim_create_buf(self.listed, true)
    self.session_to_buf[session.id] = bufnr
    vim.api.nvim_buf_set_name(bufnr, self:get_readable_bufname(session))
  end
  return self.session_to_buf[session.id]
end

---@param dap_session dap.Session
---@param chat CodeCompanion.Chat
---@param content string[]
function ScratchBufManager:update(dap_session, chat, content)
  local bufnr = self:get_bufnr(dap_session)
  local buf_name = self:get_readable_bufname(dap_session)

  if
    not vim.iter(chat.refs or {}):any(function(item)
      return item and item.source == buf_name
    end)
  then
    chat.references:add({
      bufnr = bufnr,
      source = buf_name,
      opts = {
        watched = true,
      },
      id = buf_name,
    })
  end

  local inserted_lines = {}
  if self.prefix then
    vim.list_extend(inserted_lines, vim.split(self.prefix, "\n"))
  end
  vim.list_extend(inserted_lines, content)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, inserted_lines)
end

return ScratchBufManager
