---@module "codecompanion"
---@module "dap"

local tool_name = "dap_source"

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
The request retrieves the content of a source file by source reference or path in the current DAP session.
]],
        parameters = {
          type = "object",
          properties = {
            sourceReference = {
              type = "number",
              description = "A source reference to retrieve the source content for. Use this if available.",
            },
            sourcePath = {
              type = "string",
              description = "The path to the source file to retrieve content for. Use this if 'sourceReference' is not available.",
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

        local args = {}
        if params.sourceReference ~= nil then
          args.sourceReference = params.sourceReference
        elseif params.sourcePath ~= nil then
          args.source = { path = params.sourcePath }
        else
          return {
            status = "error",
            data = "Either 'sourceReference' or 'sourcePath' must be provided.",
          }
        end

        session:request("source", args, function(err, res)
          if err == nil then
            -- Pass both content and the original sourcePath (if provided)
            cb({
              status = "success",
              data = { content = res.content, sourcePath = params.sourcePath },
            })
          else
            cb({ status = "error", data = err })
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
          string.format("**DAP Source Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param agent CodeCompanion.Agent
      success = function(_, agent, _, stdout)
        local response_data = stdout[1]
        local source_content = response_data.content
        local source_path = response_data.sourcePath

        if source_path and source_path ~= "" then
          -- If a local file path was used, display only the path
          agent.chat:add_tool_output(
            agent.tool,
            source_content,
            string.format(
              "**DAP Source Tool**: Successfully retrieved source from path: %s",
              source_path
            )
          )
        else
          -- If sourceReference was used, or no path was explicitly given, just confirm success
          agent.chat:add_tool_output(
            agent.tool,
            source_content, -- Still provide full content to the tool
            "**DAP Source Tool**: Successfully retrieved source content."
          )
        end
      end,
    },
  }
end
