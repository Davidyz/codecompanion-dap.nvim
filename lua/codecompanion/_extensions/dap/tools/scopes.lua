---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")
local tool_name = "dap_scopes"

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

        timer.call(function()
          session:request("scopes", { frameId = params.frameId }, function(err, res)
            if err == nil then
              cb({ status = "success", data = utils.convert_path(res.scopes) })
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
          string.format("**DAP Scopes Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param tools CodeCompanion.Tools
      success = function(_, tools, _, stdout)
        local scopes = stdout[#stdout]
        local num_scopes = #scopes
        tools.chat:add_tool_output(
          tools.tool,
          vim.json.encode(scopes),
          string.format("**DAP Scopes Tool**: Found %d scope(s).", num_scopes)
        )
      end,
    },
  }
end
