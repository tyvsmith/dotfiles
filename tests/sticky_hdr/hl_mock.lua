-- Mock of the `hl` global that Hyprland's Lua config exposes, covering the
-- slice sticky_hdr.lua uses: monitor(), timer(), on(), get_windows(), env().
-- Faithful where it matters: timers only fire while enabled, get_windows
-- honors a {monitor = name} filter, events fan out to every handler.

local M = {}

function M.new()
  local state = {
    applied = {}, -- every spec passed to hl.monitor, in order
    timers = {}, -- {cb, timeout, type, enabled}
    handlers = {}, -- event name -> list of callbacks
    windows = {}, -- current window list
    gw_calls = 0, -- get_windows invocation count
    monitor_error = nil, -- set to a string to make hl.monitor throw once
  }

  local hl = {}

  function hl.monitor(spec)
    if state.monitor_error then
      local err = state.monitor_error
      state.monitor_error = nil
      error(err)
    end
    table.insert(state.applied, spec)
  end

  function hl.timer(cb, opts)
    local t = { cb = cb, timeout = opts.timeout, type = opts.type, enabled = true }
    function t.set_enabled(self, v) self.enabled = v end
    function t.is_enabled(self) return self.enabled end
    function t.set_timeout(self, v) self.timeout = v end
    table.insert(state.timers, t)
    return t
  end

  function hl.on(event, cb)
    state.handlers[event] = state.handlers[event] or {}
    table.insert(state.handlers[event], cb)
  end

  function hl.get_windows(filter)
    state.gw_calls = state.gw_calls + 1
    local out = {}
    for _, w in ipairs(state.windows) do
      local ok = true
      if filter and filter.monitor then
        ok = w.monitor ~= nil and w.monitor.name == filter.monitor
      end
      if ok then table.insert(out, w) end
    end
    return out
  end

  function hl.env() end

  return hl, state
end

-- Deliver an event to every registered handler, via pcall so a throwing
-- handler doesn't kill the test run; returns false if any handler threw.
function M.fire(state, event, ...)
  local clean = true
  for _, cb in ipairs(state.handlers[event] or {}) do
    local ok = pcall(cb, ...)
    clean = clean and ok
  end
  return clean
end

-- Fire one timer the way Hyprland would: only if still enabled.
function M.fire_timer(t)
  if t and t.enabled then t.cb() end
end

-- All timers created with a given timeout (ms), for picking apart cooldown vs
-- coalesce vs prewarm vs reconcile timers by their distinct durations.
function M.timers_with_timeout(state, ms)
  local out = {}
  for _, t in ipairs(state.timers) do
    if t.timeout == ms then table.insert(out, t) end
  end
  return out
end

function M.last_applied(state)
  return state.applied[#state.applied]
end

return M
