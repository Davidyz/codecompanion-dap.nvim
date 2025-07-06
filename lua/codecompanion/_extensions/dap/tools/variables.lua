---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local tool_name = "dap_variables"

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
The request retrieves the contents of a scope or variables reference.
]],
        parameters = {
          type = "object",
          properties = {
            variablesReference = {
              type = "number",
              description = "The ID of the variables reference. This is typically obtained from a Scope or Variable object.",
            },
            filter = {
              type = "string",
              description = "Filter options for the variables. Possible values: 'indexed', 'named'.",
            },
            start = {
              type = "number",
              description = "The index of the first variable to return (0-based).",
            },
            count = {
              type = "number",
              description = "The number of variables to return.",
            },
          },
          required = { "variablesReference" },
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

        local args = { variablesReference = params.variablesReference }
        if params.filter ~= nil then
          args.filter = params.filter
        end
        if params.start ~= nil then
          args.start = params.start
        end
        if params.count ~= nil then
          args.count = params.count
        end

        timer.call(function()
          session:request("variables", args, function(err, res)
            if err == nil then
              cb({ status = "success", data = res.variables })
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
          string.format("**DAP Variables Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        local variables = stdout[1]
        local num_variables = #variables
        agent.chat:add_tool_output(
          agent.tool,
          vim.json.encode(variables),
          string.format("**DAP Variables Tool**: Found %d variable(s).", num_variables)
        )
      end,
    },
  }
end
