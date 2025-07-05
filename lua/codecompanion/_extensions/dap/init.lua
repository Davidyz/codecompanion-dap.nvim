---@module "codecompanion"

---@class CodeCompanion.DapExtension: CodeCompanion.Extension

---@class CodeCompanionDap.ToolOpts

---@alias CodeCompanionDap.ToolName "threads"

---@class CodeCompanionDap.Opts
---@field tool_opts {CodeCompanionDap.ToolName: CodeCompanionDap.ToolOpts}
---@field collapse_tools boolean
local options = {
  tool_opts = {
    scopes = {},
    source = {},
    stackTrace = {},
    threads = {},
    variables = {},
  },
  collapse_tools = true,
}

local Extension = {
  ---@param opts CodeCompanionDap.Opts|{}|nil
  setup = function(opts)
    options = vim.tbl_deep_extend("force", options, opts or {})

    local has_dap, _dap = pcall(require, "dap")
    if not has_dap or (_dap == nil) then
      error("Please install nvim-dap!")
    end

    local config = require("codecompanion.config").config
    local tool_group = {}
    for tool_name, tool_opts in pairs(options.tool_opts) do
      local full_tool_name = "dap_" .. tool_name
      config.strategies.chat.tools[full_tool_name] = {
        description = string.format("DAP %s tool", tool_name),
        callback = require(
          string.format("codecompanion._extensions.dap.tools.%s", tool_name)
        )(tool_opts),
      }
      table.insert(tool_group, full_tool_name)
    end

    config.strategies.chat.tools.groups["dap"] = {
      opts = { collapse_tools = options.collapse_tools },
      tools = tool_group,
      description = "Some tools that expose a subset of the nvim-dap API to CodeCompanion.",
    }
  end,
}

return Extension
