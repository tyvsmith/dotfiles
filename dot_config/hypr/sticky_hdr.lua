-- sticky_hdr.lua -- keep a monitor in HDR for as long as an HDR window lives,
-- not just while it is fullscreen (Hyprland's render:cm_auto_hdr flaps on
-- alt-tab). A window whose process carries a marker env var, or whose class is
-- listed, switches the monitor to the `hdr` spec until the last such window is
-- gone plus `cooldown` seconds. Usage: see hypr/monitors.lua.
--
-- M.prewarm() enters HDR ahead of any window, for launchers that probe the
-- output's color state once at startup (gamescope). The hold lasts prewarm_sec
-- (default 10s): a qualifying window arriving inside it takes over normal
-- stickiness; otherwise the hold expires and the usual cooldown revert runs.
-- The hold's deadline is persisted to $XDG_RUNTIME_DIR so it survives the
-- config reloads that recreate this Lua VM (Omarchy reloads on every save).
--
-- Hyprland 0.56 notes: monitor rules are whole-record replacements, so sdr/hdr
-- are merged over the full spec; window.close skips SIGKILL and window.destroy
-- has no address, so teardown recounts live windows; HL.Timer has no cancel(),
-- but set_enabled(false) calls a pending oneshot off -- callbacks still
-- re-check a generation counter in case one was already in flight; HL.Monitor
-- exposes cm as the configured preset and vrr_active as a live boolean, so
-- neither the color state nor the configured VRR mode can be read back, and
-- the module keeps its own flag.
--
-- Tests (mock hl): the hypr-sticky-hdr repo's tests/run.sh, mirrored in the
-- dotfiles repo as tests/sticky_hdr/run.sh.

local M = {}
M._instances = {}

local DEFAULTS = {
  sdr      = { cm = "srgb" },
  hdr      = { cm = "hdr" },
  env      = { "DXVK_HDR=1", "HYPR_STICKY_HDR=1" },
  classes  = { "gamescope" },
  cooldown_sec  = 2,
  prewarm_sec   = 10,
  reconcile_sec = 30, -- safety net for missed events; 0 disables
}

local COALESCE_MS = 100 -- window events within this batch into one scan

local STATE_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp")
  .. "/hypr-sticky-hdr-prewarm"

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

local function to_ms(v, name)
  local n = tonumber(v)
  assert(n and n >= 0 and n < math.huge,
    "sticky_hdr.setup: " .. name .. " must be a finite non-negative number")
  return math.floor(n * 1000)
end

-- The raw environ blob, or nil when it cannot be read. nil is a real
-- condition (another user namespace, a process mid-exec), distinct from "read
-- fine, no marker" -- callers must not cache it as a "no".
local function read_environ(pid)
  local f = io.open("/proc/" .. pid .. "/environ", "rb")
  if not f then return nil end
  local blob = f:read("a")
  f:close()
  return blob
end

-- Whole NUL-delimited environ entries; FOO=1 cannot match BARFOO=1.
local function environ_has_any(blob, entries)
  blob = "\0" .. blob .. "\0"
  for _, e in ipairs(entries) do
    if blob:find("\0" .. e .. "\0", 1, true) then return true end
  end
  return false
end

-- Seconds-precision deadline shared by every instance; last writer wins.
local function write_hold_deadline(sec_from_now)
  local f = io.open(STATE_FILE, "w")
  if f then
    f:write(tostring(os.time() + sec_from_now))
    f:close()
  end
end

local function persisted_hold_ms(cap_ms)
  local f = io.open(STATE_FILE, "r")
  if not f then return 0 end
  local deadline = tonumber(f:read("a"))
  f:close()
  if not deadline then return 0 end
  local remaining = (deadline - os.time()) * 1000
  if remaining <= 0 then return 0 end
  return math.min(math.floor(remaining), cap_ms)
end

--- Start managing one monitor. Returns a handle with .wants_hdr() (real
--- window demand, prewarm holds excluded), .in_hdr(), and .prewarm().
function M.setup(opts)
  assert(type(opts) == "table" and type(opts.monitor) == "table",
    "sticky_hdr.setup: opts.monitor (an hl.monitor spec) is required")

  local SDR     = merged(opts.monitor, opts.sdr or DEFAULTS.sdr)
  local HDR     = merged(opts.monitor, opts.hdr or DEFAULTS.hdr)
  local ENV     = opts.env or DEFAULTS.env
  local CLASSES = to_set(opts.classes or DEFAULTS.classes)
  local READ    = opts.environ_reader or read_environ
  local COOLDOWN_MS  = to_ms(opts.cooldown_sec or DEFAULTS.cooldown_sec, "cooldown_sec")
  local PREWARM_MS   = to_ms(opts.prewarm_sec or DEFAULTS.prewarm_sec, "prewarm_sec")
  local RECONCILE_MS = to_ms(opts.reconcile_sec or DEFAULTS.reconcile_sec, "reconcile_sec")

  -- Demand is scoped to this instance's output; "" manages every output, so
  -- it sees every window.
  local OUTPUT = opts.monitor.output or ""
  local FILTER = OUTPUT ~= "" and { monitor = OUTPUT } or nil

  local env_wants     = {} -- pid -> bool, so /proc is read once per process
  local in_hdr        = false
  local last_want     = false
  local prewarm_gen   = 0 -- overlapping holds: only the newest timer may end one
  local cooldown_gen  = 0 -- ditto for cooldown reverts
  local cooldown_timer = nil
  local coalesce_timer = nil
  local prune_pending  = false

  local function window_wants_hdr(w)
    if CLASSES[w.class] then return true end
    local pid = w.pid
    if not pid or pid <= 0 then return false end
    local verdict = env_wants[pid]
    if verdict == nil then
      local blob = READ(pid)
      if blob == nil then return false end -- transient: retry next event
      verdict = environ_has_any(blob, ENV)
      env_wants[pid] = verdict
    end
    return verdict
  end

  local function window_demand()
    for _, w in ipairs(hl.get_windows(FILTER)) do
      if window_wants_hdr(w) then return true end
    end
    return false
  end

  local function demand()
    return prewarm_gen > 0 or window_demand()
  end

  -- Verdicts die with their windows, or PID reuse would serve a stale one.
  local function prune_cache()
    local live = {}
    for _, w in ipairs(hl.get_windows()) do
      if w.pid then live[w.pid] = true end
    end
    for pid in pairs(env_wants) do
      if not live[pid] then env_wants[pid] = nil end
    end
  end

  local function invalidate_cooldown()
    cooldown_gen = cooldown_gen + 1
    if cooldown_timer then
      cooldown_timer:set_enabled(false)
      cooldown_timer = nil
    end
  end

  -- Always a fresh full-length timer, so the cooldown runs from the LAST
  -- demand end -- a window opening and closing during a pending cooldown must
  -- not inherit the old, nearly expired deadline.
  local function arm_cooldown()
    invalidate_cooldown()
    local gen = cooldown_gen
    cooldown_timer = hl.timer(function()
      if gen ~= cooldown_gen then return end
      cooldown_timer = nil
      if in_hdr and not demand() then
        hl.monitor(SDR)
        in_hdr = false
        last_want = false
      end
    end, { timeout = COOLDOWN_MS, type = "oneshot" })
  end

  -- State flags follow the hl calls, never precede them: if a call throws,
  -- the next event retries instead of finding the flag already latched.
  local function sync()
    if prune_pending then
      prune_pending = false
      prune_cache()
    end
    local want = demand()
    if want then
      invalidate_cooldown()
      if not in_hdr then
        hl.monitor(HDR)
        in_hdr = true
      end
    elseif in_hdr and (last_want or cooldown_timer == nil) then
      arm_cooldown()
    end
    last_want = want
  end

  -- One immediate sync per burst; the rest coalesce into a trailing re-check.
  local function schedule_sync()
    if coalesce_timer then return end
    sync()
    coalesce_timer = hl.timer(function()
      coalesce_timer = nil
      sync()
    end, { timeout = COALESCE_MS, type = "oneshot" })
  end

  hl.on("window.open", schedule_sync)
  hl.on("window.close", function()
    prune_pending = true
    schedule_sync()
  end)
  hl.on("window.destroy", function()
    prune_pending = true
    schedule_sync()
  end)

  -- A monitor coming back re-applies Hyprland's own rules, wiping ours -- in
  -- BOTH directions: without re-asserting, an SDR desktop loses this spec's
  -- bitdepth/vrr and an HDR game drops to the default preset. Other outputs'
  -- hotplugs are none of this instance's business (a dock display appearing
  -- must not modeset the game monitor).
  hl.on("monitor.added", function(mon)
    if OUTPUT ~= "" and mon and mon.name and mon.name ~= OUTPUT then return end
    invalidate_cooldown()
    local want = demand()
    hl.monitor(want and HDR or SDR)
    in_hdr = want
    last_want = want
  end)

  -- Missed or early events (see the 0.56 notes above) would otherwise pin a
  -- state forever; a periodic re-check is the backstop.
  if RECONCILE_MS > 0 then
    hl.timer(sync, { timeout = RECONCILE_MS, type = "repeat" })
  end

  local function hold(ms)
    prewarm_gen = prewarm_gen + 1
    local gen = prewarm_gen
    hl.timer(function()
      if gen ~= prewarm_gen then return end
      prewarm_gen = 0
      os.remove(STATE_FILE) -- a dead hold must not resurrect on reload
      sync()
    end, { timeout = ms, type = "oneshot" })
  end

  local function prewarm()
    write_hold_deadline(PREWARM_MS / 1000)
    hold(PREWARM_MS)
    sync()
  end

  -- Baseline. Adopts windows that already exist, and resumes a persisted
  -- prewarm hold, so a config reload mid-game or mid-launch does not flash
  -- SDR right as gamescope probes the output.
  local resume_ms = persisted_hold_ms(PREWARM_MS)
  if resume_ms > 0 then hold(resume_ms) end
  local want = demand()
  hl.monitor(want and HDR or SDR)
  in_hdr = want
  last_want = want

  local handle = {
    wants_hdr = window_demand,
    in_hdr    = function() return in_hdr end,
    prewarm   = prewarm,
  }
  table.insert(M._instances, handle)
  return handle
end

--- Enter HDR on every managed monitor before a launcher probes the output.
--- Called from outside the VM: hyprctl eval "require('hypr.sticky_hdr').prewarm()"
function M.prewarm()
  for _, h in ipairs(M._instances) do h.prewarm() end
end

return M
