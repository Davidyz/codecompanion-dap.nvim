---@module "codecompanion"
---@module "dap"

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
          },
          required = { "action" },
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
      end,
    },
    output = {
      ---@param self CodeCompanion.Agent.Tool
      ---@param agent CodeCompanion.Agent
      error = function(self, agent, _, stderr)
        stderr = table.concat(vim.iter(stderr):flatten(math.huge):totable(), "\n")
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
          string.format("**DAP Stepping Tool**: %s", stdout[1])
        )
      end,
    },
  }
end
