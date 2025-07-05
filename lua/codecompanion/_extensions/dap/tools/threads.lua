---@module "codecompanion"
---@module "dap"

local tool_name = "dap_threads"

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
The request retrieves a list of all threads in the current DAP session. Calling it once will return all ongoing threads.
  ]],
      },
    },
    cmds = {
      function(_, _, _, cb)
        local ok, dap = pcall(require, "dap")
        if not ok then
          return { status = "error", data = "nvim-dap not found." }
        end
        local session = dap.session()
        if session == nil then
          return { status = "error", data = "Couldn't find a running session." }
        end
        session:request("threads", {}, function(err, res)
          if err == nil then
            cb({ status = "success", data = res.threads })
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
        agent.chat:add_tool_output(
          self,
          stderr,
          string.format("**DAP Threads Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        agent.chat:add_tool_output(
          agent.tool,
          vim.json.encode(stdout[1]),
          string.format("**DAP Threads Tool**: Found %d thread(s).", #stdout[1])
        )
      end,
    },
  }
end
