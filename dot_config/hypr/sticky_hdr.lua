-- sticky_hdr.lua -- keep a monitor in HDR for as long as an HDR window lives,
-- not just while it is fullscreen (Hyprland's render:cm_auto_hdr flaps on
-- alt-tab). A window whose process carries a marker env var, or whose class is
-- listed, switches the monitor to the `hdr` spec until the last such window is
-- gone plus `cooldown` seconds. Usage: see hypr/monitors.lua.
--
-- Hyprland 0.56 notes: monitor rules are whole-record replacements, so sdr/hdr
-- are merged over the full spec; window.close skips SIGKILL and window.destroy
-- has no address, so teardown recounts live windows; HL.Timer has no cancel(),
-- so the cooldown timer re-checks demand; HL.Monitor.cm is the configured
-- preset, not live state, so the module keeps its own flag.

local M = {}

local DEFAULTS = {
  sdr      = { cm = "srgb" },
  hdr      = { cm = "hdr" },
  env      = { "PROTON_ENABLE_HDR=1", "HYPR_STICKY_HDR=1" },
  classes  = {},
  cooldown = 2,
}

local function merged(base, over)
  local t = {}
  for k, v in pairs(base) do t[k] = v end
  for k, v in pairs(over or {}) do t[k] = v end
  return t
end

local function to_set(list)
  local s = {}
  for _, v in ipairs(list or {}) do s[v] = true end
  return s
end

-- Whole NUL-delimited environ entries; FOO=1 cannot match BARFOO=1.
local function environ_has_any(pid, entries)
  local f = io.open("/proc/" .. pid .. "/environ", "rb")
  if not f then return false end
  local blob = "\0" .. (f:read("a") or "") .. "\0"
  f:close()
  for _, e in ipairs(entries) do
    if blob:find("\0" .. e .. "\0", 1, true) then return true end
  end
  return false
end

--- Start managing one monitor. Returns a handle with :wants_hdr(), :in_hdr().
function M.setup(opts)
  assert(type(opts) == "table" and type(opts.monitor) == "table",
    "sticky_hdr.setup: opts.monitor (an hl.monitor spec) is required")

  local SDR      = merged(opts.monitor, opts.sdr or DEFAULTS.sdr)
  local HDR      = merged(opts.monitor, opts.hdr or DEFAULTS.hdr)
  local ENV      = opts.env or DEFAULTS.env
  local CLASSES  = to_set(opts.classes or DEFAULTS.classes)
  local COOLDOWN = math.floor((opts.cooldown or DEFAULTS.cooldown) * 1000)

  local env_wants = {} -- pid -> bool, so /proc is read once per process
  local in_hdr    = false
  local pending   = false

  local function window_wants_hdr(w)
    if CLASSES[w.class] then return true end
    local pid = w.pid
    if not pid or pid <= 0 then return false end
    if env_wants[pid] == nil then env_wants[pid] = environ_has_any(pid, ENV) end
    return env_wants[pid]
  end

  local function demand()
    for _, w in ipairs(hl.get_windows()) do
      if window_wants_hdr(w) then return true end
    end
    return false
  end

  local function sync()
    local want = demand()
    if want and not in_hdr then
      in_hdr = true
      hl.monitor(HDR)
    elseif not want and in_hdr and not pending then
      pending = true
      hl.timer(function()
        pending = false
        if not demand() then
          in_hdr = false
          hl.monitor(SDR)
        end
      end, { timeout = COOLDOWN, type = "oneshot" })
    end
  end

  hl.on("window.open", sync)
  hl.on("window.close", sync)
  hl.on("window.destroy", sync)
  -- A monitor coming back re-applies Hyprland's own rules, wiping ours.
  hl.on("monitor.added", function()
    in_hdr = false
    sync()
  end)

  -- Baseline. Adopts windows that already exist so a config reload mid-game
  -- does not flash SDR.
  in_hdr = demand()
  hl.monitor(in_hdr and HDR or SDR)

  return {
    wants_hdr = demand,
    in_hdr    = function() return in_hdr end,
  }
end

return M
