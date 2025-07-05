---@module "codecompanion"
---@module "dap"

local tool_name = "dap_source"

---@class CodeCompanionDap.SourceTool.Opts: CodeCompanionDap.ToolOpts
---@field prefer_filesystem boolean

---@param opts CodeCompanionDap.SourceTool.Opts
---@return CodeCompanion.Agent.Tool
return function(opts)
  opts = vim.tbl_deep_extend("force", { prefer_filesystem = true }, opts or {})
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
          required = { "sourceReference" },
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
          local path = vim.fs.normalize(params.sourcePath)
          local stat = vim.uv.fs_stat(path)
          if opts.prefer_filesystem and stat and stat.type == "file" then
            local fd = vim.uv.fs_open(path, "r", 438)
            if fd == nil or stat == nil or stat.size == nil then
              return {
                status = "error",
                data = string.format("Failed to open %s", path),
              }
            end
            assert(type(stat.size) == "number", "Invalid file stat!")
            local content, err = vim.uv.fs_read(fd, stat.size, 0)
            vim.uv.fs_close(fd)
            if content then
              return {
                status = "success",
                data = { content = content, sourcePath = path },
              }
            else
              return { status = "error", data = err }
            end
          end
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
