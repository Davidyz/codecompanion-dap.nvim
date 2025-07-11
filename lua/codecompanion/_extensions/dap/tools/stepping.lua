---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local tool_name = "dap_stepping"

---@param opts CodeCompanionDap.ToolOpts
---@return CodeCompanion.Agent.Tool
return function(opts)
  ---@type CodeCompanion.Agent.Tool|{}
  return {
    name = tool_name,
    schema = {
      type = "function",
      ["function"] = {
        name = tool_name,
        description = [[
The request provides stepping functionalities for the current DAP session.
Each `stepping` call should be followed by a `stackTrace` call using the current `threadId` to verify whether the stepping worked as intended.
The `stackTrace` call should be in the same request as the `stepping` call if possible.
If you need to call stepIn, call `stepInTargets` first to verify the stepIn is possible.
]],
        parameters = {
          type = "object",
          properties = {
            action = {
              type = "string",
              description = "The stepping action to perform.",
              enum = { "stepIn", "stepOut", "stepBack", "next", "continue" },
            },
            threadId = {
              type = "number",
              description = "The ID of the thread for which to perform the stepping action. If omitted, the currently selected thread is used.",
            },
            granularity = {
              type = "string",
              description = "The granularity of one step. If omitted, 'statement' is assumed.",
              enum = { "statement", "line", "instruction" },
            },
            targetId = {
              type = "number",
              description = "The ID of the step target to step to. ONLY PASS THIS VALUE IF OBTAINED FROM `StepInTargets` REQUESTS.",
            },
          },
          required = { "action", "threadId" },
        },
      },
    },
    cmds = {
      function(_, params, _, cb)
        local ok, dap = pcall(require, "dap")
        if not ok then
          return { status = "error", data = "nvim-dap not found." }
        end
        local session = dap.session()
        if session == nil then
          return { status = "error", data = "Couldn't find a running session." }
        end

        if not params.action then
          return {
            status = "error",
            data = string.format(
              "Invalid stepping action: '%s'. Must be 'in', 'out', or 'back'.",
              params.action
            ),
          }
        end

        local args = vim.empty_dict()
        if params.threadId ~= nil then
          args.threadId = params.threadId
        end
        if params.granularity ~= nil and params.action ~= "continue" then
          args.granularity = params.granularity
        end
        if params.targetId and params.action == "stepIn" then
          args.targetId = params.targetId
        end

        timer.call(function()
          session:request(params.action, args, function(err, res)
            if err == nil then
              cb({
                status = "success",
                data = string.format("Stepping action '%s' completed.", params.action),
              })
            else
              cb({ status = "error", data = err.message })
            end
          end)
        end)
      end,
    },
    output = {
      ---@param self CodeCompanion.Agent.Tool
      ---@param agent CodeCompanion.Agent
      error = function(self, agent, _, stderr)
        if type(stderr) == "table" then
          stderr = table.concat(vim.iter(stderr):flatten(math.huge):totable(), "\n")
        end
        agent.chat:add_tool_output(
          self,
          stderr,
          string.format("**DAP Stepping Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        agent.chat:add_tool_output(
          agent.tool,
          stdout[1],
          string.format("**DAP Stepping Tool**: %s", stdout[#stdout])
        )
      end,
    },
  }
end
