---@module "codecompanion"
---@module "dap"

local tool_name = "dap_stepInTargets"
local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")

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
The request retrieves possible step-in targets for the current DAP session.
]],
        parameters = {
          type = "object",
          properties = {
            frameId = {
              type = "number",
              description = "The ID of the frame for which to retrieve step-in targets.",
            },
          },
          required = { "frameId" },
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

        local args = vim.empty_dict()
        if params.frameId ~= nil then
          args.frameId = params.frameId
        end

        timer.call(function()
          session:request("stepInTargets", args, function(err, res)
            if err == nil then
              cb({
                status = "success",
                data = utils.convert_path(res.targets) or {},
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
          string.format("**DAP StepInTargets Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        agent.chat:add_tool_output(
          agent.tool,
          vim.json.encode(stdout[#stdout]),
          string.format(
            "**DAP StepInTargets Tool**: Found %d target(s).",
            #stdout[#stdout]
          )
        )
      end,
    },
  }
end
