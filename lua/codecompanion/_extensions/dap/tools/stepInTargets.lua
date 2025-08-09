---@module "codecompanion"
---@module "dap"

local tool_name = "dap_stepInTargets"
local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")

return function(opts)
  local scratch_buf_manager = require("codecompanion._extensions.dap.scratch_buf").new({
    bufname_prefix = "stepInTargets",
  })
  ---@type CodeCompanion.Tools.Tool|{}
  return {
    name = tool_name,
    schema = {
      type = "function",
      ["function"] = {
        name = tool_name,
        description = [[
The request retrieves possible step-in targets for the current DAP session.
When you need to investigate the behaviour of a particular symbol (function, class, etc.),
you should use this tool to find out whether you can step into it's implementation before calling the stepping tool.
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
                data = utils.convert_path(res.targets),
              })
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
      error = function(self, tools, _, stderr)
        if type(stderr) == "table" then
          stderr = table.concat(vim.iter(stderr):flatten(math.huge):totable(), "\n")
        end
        tools.chat:add_tool_output(
          self,
          stderr,
          string.format("**DAP StepInTargets Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param tools CodeCompanion.Tools
      success = function(_, tools, _, stdout)
        local targets = stdout[#stdout]
        local dap = require("dap")

        local lines = vim
          .iter(targets)
          :map(function(target)
            return vim.trim(vim.json.encode(target))
          end)
          :totable()

        local session = dap.session()
        if session == nil then
          return tools.chat:add_tool_output(
            tools.tool,
            "The DAP session is no longer active."
          )
        end

        scratch_buf_manager:update(session, tools.chat, lines)

        local num_targets = #targets
        tools.chat:add_tool_output(
          tools.tool,
          string.format(
            "The step-in targets are available in the buffer named `%s`.",
            scratch_buf_manager:get_readable_bufname(session)
          ),
          string.format("**DAP StepInTargets Tool**: Found %d target(s).", num_targets)
        )
      end,
    },
  }
end
