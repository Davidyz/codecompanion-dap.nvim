---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local tool_name = "dap_stackTrace"

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
The request retrieves the call stack for a given thread in the current DAP session.
]],
        parameters = {
          type = "object",
          properties = {
            threadId = {
              type = "number",
              description = "The ID of the thread for which to retrieve the stack trace.",
            },
            startFrame = {
              type = "number",
              description = "The index of the first frame to return (0-based). If omitted, the first frame is returned.",
            },
            levels = {
              type = "number",
              description = "The maximum number of frames to return. If omitted, all frames are returned.",
            },
          },
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

        local args = { threadId = params.threadId or 0 }
        if params.startFrame ~= nil then
          args.startFrame = params.startFrame
        end
        if params.levels ~= nil then
          args.levels = params.levels
        end

        timer.call(function()
          session:request("stackTrace", args, function(err, res)
            if err == nil then
              cb({ status = "success", data = res.stackFrames })
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
          string.format("**DAP Stack Trace Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        local stack_frames = stdout[#stdout]
        local num_frames = #stack_frames
        agent.chat:add_tool_output(
          agent.tool,
          vim.json.encode(stack_frames),
          string.format(
            "**DAP Stack Trace Tool**: Found %d stack frame(s).",
            num_frames
          )
        )
      end,
    },
  }
end
