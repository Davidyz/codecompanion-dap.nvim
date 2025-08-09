---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")
local tool_name = "dap_evaluate"

---@param opts CodeCompanionDap.ToolOpts
---@return CodeCompanion.Tools.Tool
return function(opts)
  ---@type CodeCompanion.Tools.Tool|{}
  return {
    name = tool_name,
    schema = {
      type = "function",
      ["function"] = {
        name = tool_name,
        description = [[
Evaluates an expression in the context of the debuggee and returns its value.
]],
        parameters = {
          type = "object",
          properties = {
            expression = {
              type = "string",
              description = "The expression to evaluate.",
            },
            frameId = {
              type = "number",
              description = "The ID of the stack frame in whose scope the expression should be evaluated.",
            },
            context = {
              type = "string",
              description = "The context in which the evaluate request is run. Possible values: 'repl', 'variables', 'watch', 'hover', 'clipboard'.",
            },
          },
          required = { "expression" },
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

        local args = { expression = params.expression }
        if params.frameId ~= nil then
          args.frameId = params.frameId
        end
        if params.context ~= nil then
          args.context = params.context
        end

        timer.call(function()
          session:request("evaluate", args, function(err, res)
            if err == nil then
              cb({ status = "success", data = utils.convert_path(res) })
            else
              cb({ status = "error", data = err.message })
            end
          end)
        end)
      end,
    },
    output = {
      ---@param self CodeCompanion.Tools.Tool
      ---@param tools CodeCompanion.Tools
      prompt = function(self, tools)
        return string.format("Evaluate `%s`?", self.args.expression)
      end,
      ---@param self CodeCompanion.Tools.Tool
      ---@param tools CodeCompanion.Tools
      error = function(self, tools, _, stderr)
        if type(stderr) == "table" then
          stderr = table.concat(vim.iter(stderr):flatten(math.huge):totable(), "\n")
        end
        tools.chat:add_tool_output(
          self,
          stderr,
          string.format("**DAP Evaluate Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param tools CodeCompanion.Tools
      success = function(_, tools, action, stdout)
        local result = stdout[#stdout].result
        local variablesReference = stdout[#stdout].variablesReference
        local output_message = string.format(
          "**DAP Evaluate Tool**: Expression `%s` evaluated to: `%s`",
          action.expression,
          tostring(result)
        )

        if variablesReference and variablesReference > 0 then
          output_message = output_message
            .. string.format(" (variablesReference: %d)", variablesReference)
        end

        tools.chat:add_tool_output(
          tools.tool,
          vim.json.encode(stdout[#stdout]),
          output_message
        )
      end,
    },
  }
end
