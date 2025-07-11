---@module "codecompanion"

---@class CodeCompanion.DapExtension: CodeCompanion.Extension

---@class CodeCompanionDap.ToolOpts
---@field requires_approval? boolean

---@class CodeCompanionDap.Opts
---@field tool_opts {string: CodeCompanionDap.ToolOpts}
---@field collapse_tools boolean
---@field interval_ms? integer
---@field winfixbuf? boolean
local options = {
  tool_opts = {
    breakpoints = {},
    evaluate = { requires_approval = true },
    scopes = {},
    source = {},
    stackTrace = {},
    stepping = {},
    stepInTargets = {},
    stopped_at = {},
    threads = {},
    variables = {},
  },
  collapse_tools = true,
  interval_ms = 1000,
  winfixbuf = true,
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
      if tool_opts then
        local full_tool_name = "dap_" .. tool_name
        config.strategies.chat.tools[full_tool_name] = {
          description = string.format("DAP %s tool", tool_name),
          callback = require(
            string.format("codecompanion._extensions.dap.tools.%s", tool_name)
          )(tool_opts),
          opts = { requires_approval = tool_opts.requires_approval },
        }
        table.insert(tool_group, full_tool_name)
      end
    end

    config.strategies.chat.tools.groups["dap"] = {
      opts = { collapse_tools = options.collapse_tools },
      tools = tool_group,
      description = "Some tools that expose a subset of the nvim-dap API to CodeCompanion.",
    }
    require("codecompanion._extensions.dap.timer").setup({
      interval_ms = options.interval_ms,
    })
    if options.winfixbuf then
      vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatOpened",
        callback = function()
          vim.wo.winfixbuf = true
        end,
      })
    end

    require("dap").listeners.after["event_terminated"]["codecompanion-dap"] = function(
      session,
      _
    )
      vim.api.nvim_exec_autocmds("User", {
        pattern = "CodeCompanionDapSessionTerminated",
        data = { session_id = session.id },
      })
    end
    require("dap").listeners.after["event_stopped"]["codecompanion-dap"] = function(
      session,
      event
    )
      vim.api.nvim_exec_autocmds("User", {
        pattern = "CodeCompanionDapSessionStopped",
        data = { session_id = session.id, event = event },
      })
    end
  end,
}

return Extension
