---@type integer
local last_req = nil

---@class CodeCompanionDap.TimerOpts
---@field interval_ms integer interval between 2 calls.
local timer_opts = { interval_ms = 1000 }

local M = {
  setup = function(opts)
    timer_opts = vim.tbl_deep_extend("force", timer_opts, opts or {})
  end,
}

local get_curr_time_ms = function()
  local curr_time = vim.uv.clock_gettime("monotonic")
  assert(curr_time ~= nil, "Failed to obtain the current time.")
  return curr_time.nsec / 1e6 + curr_time.sec * 1e3
end

---@param fun function
function M.call(fun)
  local curr_time = get_curr_time_ms()
  if last_req == nil or timer_opts.interval_ms <= 0 then
    last_req = curr_time
    fun()
    return
  end

  local next_allowed_time = last_req + timer_opts.interval_ms
  local delay = math.max(0, next_allowed_time - curr_time)

  last_req = curr_time + delay

  if delay > 0 then
    vim.defer_fn(fun, delay)
  else
    fun()
  end
end

return M
