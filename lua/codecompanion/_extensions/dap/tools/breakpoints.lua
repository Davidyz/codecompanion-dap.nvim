---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")
local tool_name = "dap_breakpoints"

---@param opts CodeCompanionDap.ToolOpts
---@return CodeCompanion.Agent.Tool
return function(opts)
  opts = vim.tbl_deep_extend("force", {}, opts or {})
  ---@type CodeCompanion.Agent.Tool|{}
  return {
    name = tool_name,
    schema = {
      type = "function",
      ["function"] = {
        name = tool_name,
        description = [[
Sets or lists breakpoints in the current DAP session.
- To set breakpoints: provide the 'source' and 'breakpoints' arguments. The 'breakpoints' argument is a list of objects, each with a 'line' number.
- To clear all breakpoints in a file: provide 'source' and an empty 'breakpoints' list.
- To list all active breakpoints: call the tool with no arguments.
]],
        parameters = {
          type = "object",
          properties = {
            source = {
              type = "object",
              description = "The source file to set breakpoints in. ALWAYS SUPPLY THIS PARAMETER!",
              properties = {
                path = {
                  type = "string",
                  description = "The path of the source file. ALWAYS SUPPLY THIS PARAMETER!",
                },
              },
              required = { "path" },
            },
            breakpoints = {
              type = "array",
              description = "A list of breakpoints to set. Set this argument to `null` to list all existing breakpoints. Pass an empty array to clear existing breakpoints.",
              items = {
                type = "object",
                properties = {
                  line = {
                    type = "number",
                    description = "The line number to set the breakpoint on.",
                  },
                  condition = {
                    type = "string",
                    description = "A condition that must be met for the breakpoint to trigger.",
                  },
                  hitCondition = {
                    type = "string",
                    description = "A condition based on the number of times the breakpoint is hit.",
                  },
                  logMessage = {
                    type = "string",
                    description = "A message to log to the console when the breakpoint is hit.",
                  },
                },
                required = { "line" },
              },
            },
          },
          required = { "source" },
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
          return {
            status = "error",
            data = "Couldn't find a running session to set breakpoints.",
          }
        end

        if params.source == nil or params.source.path == nil then
          return {
            status = "error",
            data = "The 'source' argument with a 'path' is required when setting breakpoints.",
          }
        end

        local path = vim.fs.normalize(params.source.path)
        path = vim.fs.relpath(vim.uv.cwd() or ".", path) or path

        local args = {
          source = { path = path },
          breakpoints = params.breakpoints or {},
        }

        -- This is an asynchronous request to the DAP server.
        timer.call(function()
          session:request("setBreakpoints", args, function(err, res)
            if err == nil then
              -- The response contains the list of breakpoints that were actually verified and set by the debugger.
              cb({
                status = "success",
                data = {
                  source = { path = path },
                  breakpoints = res.breakpoints,
                },
              })
            else
              cb({ status = "error", data = err.message })
            end
          end)
        end)
      end,
    },
    output = {
      error = function(self, agent, _, stderr)
        if type(stderr) == "table" then
          stderr = table.concat(vim.iter(stderr):flatten(math.huge):totable(), "\n")
        end
        agent.chat:add_tool_output(
          self,
          stderr,
          string.format("**DAP Breakpoints Tool**: Failed with error:\n%s", stderr)
        )
      end,
      success = function(_, agent, _, stdout)
        local response_data = utils.convert_path(stdout[#stdout])

        local count = #response_data.breakpoints

        -- Check if we were setting breakpoints or listing them
        if response_data.source and response_data.source.path then
          local message
          if count > 0 then
            message = string.format(
              "**DAP Breakpoints Tool**: Successfully set %d verified breakpoints in %s.",
              count,
              response_data.source.path
            )
          else
            message = string.format(
              "**DAP Breakpoints Tool**: Cleared all breakpoints in %s.",
              response_data.source.path
            )
          end
          agent.chat:add_tool_output(
            agent.tool,
            vim.json.encode(response_data),
            message
          )
        else
          agent.chat:add_tool_output(
            agent.tool,
            vim.json.encode(response_data),
            string.format(
              "**DAP Breakpoints Tool**: Found %d active breakpoints.",
              count
            )
          )
        end
      end,
    },
  }
end
