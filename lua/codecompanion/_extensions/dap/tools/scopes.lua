---@module "codecompanion"
---@module "dap"

local tool_name = "dap_scopes"

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
The request retrieves the scopes for a given stackframe in the current DAP session.
]],
        parameters = {
          type = "object",
          properties = {
            frameId = {
              type = "number",
              description = "The ID of the stack frame for which to retrieve the scopes.",
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

        session:request("scopes", { frameId = params.frameId }, function(err, res)
          if err == nil then
            cb({ status = "success", data = res.scopes })
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
          string.format("**DAP Scopes Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        local scopes = stdout[1]
        local num_scopes = #scopes
        agent.chat:add_tool_output(
          agent.tool,
          vim.json.encode(scopes),
          string.format("**DAP Scopes Tool**: Found %d scope(s).", num_scopes)
        )
      end,
    },
  }
end
