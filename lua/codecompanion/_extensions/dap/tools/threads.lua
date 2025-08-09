---@module "codecompanion"
---@module "dap"

local timer = require("codecompanion._extensions.dap.timer")
local utils = require("codecompanion._extensions.dap.utils")
local tool_name = "dap_threads"

---@param opts CodeCompanionDap.ToolOpts
---@return CodeCompanion.Tools.Tool
return function(opts)
  local scratch_buf_manager = require("codecompanion._extensions.dap.scratch_buf").new({
    bufname_prefix = "threads",
  })
  ---@type CodeCompanion.Tools.Tool|{}
  return {
    name = tool_name,
    schema = {
      type = "function",
      ["function"] = {
        name = tool_name,
        description = [[
The request retrieves a list of all threads in the current DAP session. Calling it once will return all ongoing threads.
This should be called before you're calling another dap tool that requires `threadId` as a parameter.
  ]],
        parameters = {
          type = "object",
          properties = vim.empty_dict(),
          required = {},
          additionalProperties = false,
        },
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

        timer.call(function()
          session:request("threads", {}, function(err, res)
            if err == nil then
              cb({ status = "success", data = utils.convert_path(res.threads) })
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
          string.format("**DAP Threads Tool**: Failed with error:\n%s", stderr)
        )
      end,
      ---@param tools CodeCompanion.Tools
      success = function(_, tools, _, stdout)
        local threads = stdout[#stdout]
        local dap = require("dap")

        local lines = vim
          .iter(threads)
          :map(function(thread)
            return vim.trim(vim.json.encode(thread))
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

        local num_threads = #threads
        tools.chat:add_tool_output(
          tools.tool,
          string.format(
            "The threads are available in the buffer named `%s`.",
            scratch_buf_manager:get_readable_bufname(session)
          ),
          string.format("**DAP Threads Tool**: Found %d thread(s).", num_threads)
        )
      end,
    },
  }
end
