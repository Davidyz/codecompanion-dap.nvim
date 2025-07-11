---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")
local tool_name = "dap_stopped_at"

---@type table<integer, dap.StoppedEvent>
local stopped_at_data = {}

---@param opts CodeCompanionDap.ToolOpts
---@return CodeCompanion.Agent.Tool
return function(opts)
  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionDapSessionStopped",
    callback = function(args)
      stopped_at_data[args.data.session_id] = args.data.event
    end,
  })

  ---@type CodeCompanion.Agent.Tool|{}
  return {
    name = tool_name,
    schema = {
      type = "function",
      ["function"] = {
        name = tool_name,
        description = [[
Returns the current position that the debugee is stopped at, as well as the reasons for the stop, if available.
CALL THIS TOOL AFTER RECIEVING A USER INSTRUCTION, OR AFTER CALLING THE `dap_stepping` TOOL.
If this tool fails to return the info, you may try to call the `stepInto` request in `dap_stepping` to trigger the update, unless the user instructed otherwise.
  ]],
      },
    },
    cmds = {
      function()
        return { status = "success" }
      end,
    },
    output = {
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, _)
        local dap = require("dap")
        local session = dap.session()
        if session == nil then
          return agent.chat:add_tool_output(
            agent.tool,
            "The DAP session is no longer active."
          )
        end

        if stopped_at_data[session.id] == nil then
          return agent.chat:add_tool_output(agent.tool, "Unable to find the stop info.")
        end

        agent.chat:add_tool_output(
          agent.tool,
          vim.json.encode(stopped_at_data[session.id]),
          string.format(
            "The debuggee is stopped due to `%s`.",
            stopped_at_data[session.id].reason
          )
        )
      end,
    },
  }
end
