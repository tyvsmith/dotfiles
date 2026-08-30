-- Behavior tests for sticky_hdr.lua, run against a mock `hl`.
-- Run via ./run.sh, which sets HYPR_STICKY_HDR=1 (for the real-/proc test) and
-- a throwaway XDG_RUNTIME_DIR (for prewarm persistence).

local DIR = (arg[0]:match("^(.*/)") or "./")
local MOCK = dofile(DIR .. "hl_mock.lua")
local SRC = DIR .. "../../dot_config/hypr/sticky_hdr.lua"

local RT = assert(os.getenv("XDG_RUNTIME_DIR"), "run via run.sh: XDG_RUNTIME_DIR unset")
local STATE_FILE = RT .. "/hypr-sticky-hdr-prewarm"

local COOLDOWN_MS = 2000
local PREWARM_MS = 10000
local COALESCE_MS = 100

-- Timeouts used by pids that must not exist (beyond default pid_max 4194304).
local GHOST_A, GHOST_B, GHOST_C = 4900001, 4900002, 4900003

local self_pid = tonumber(assert(io.open("/proc/self/stat")):read("a"):match("^(%d+)"))

local passed, failed = 0, {}
local function T(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    table.insert(failed, name .. ": " .. tostring(err))
  end
end

local function eq(got, want, label)
  if got ~= want then
    error(string.format("%s: got %s, want %s", label or "value", tostring(got), tostring(want)), 2)
  end
end

local function fresh(keep_state)
  if not keep_state then os.remove(STATE_FILE) end
  local hl, state = MOCK.new()
  _G.hl = hl
  local mod = assert(loadfile(SRC))()
  return mod, hl, state
end

local function mkopts(extra)
  local o = { monitor = { output = "", mode = "preferred", bitdepth = 10 } }
  for k, v in pairs(extra or {}) do o[k] = v end
  return o
end

local function win(state, fields)
  local w = {
    address = "0xw" .. tostring(#state.windows + 1),
    pid = fields.pid,
    class = fields.class or "app",
    monitor = fields.output and { name = fields.output } or nil,
  }
  table.insert(state.windows, w)
  return w
end

local function remove_win(state, w)
  for i, x in ipairs(state.windows) do
    if x == w then table.remove(state.windows, i) return end
  end
end

-- Fire any pending coalesce timers so event-driven syncs settle. A no-op on a
-- module without coalescing.
local function settle(state)
  for _, t in ipairs(MOCK.timers_with_timeout(state, COALESCE_MS)) do
    MOCK.fire_timer(t)
    t.enabled = false
  end
end

local function cm_of(spec) return spec and spec.cm end

-- 1. Sanity: a window of a listed class flips the monitor to the hdr spec.
T("class_window_triggers_hdr", function()
  local mod, _, state = fresh()
  mod.setup(mkopts())
  eq(cm_of(MOCK.last_applied(state)), "srgb", "baseline")
  win(state, { class = "gamescope" })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "after gamescope opens")
end)

-- 2. Sanity: the default /proc reader detects a marker env var (our own).
T("marker_env_via_default_reader", function()
  assert(os.getenv("HYPR_STICKY_HDR") == "1", "run via run.sh: HYPR_STICKY_HDR unset")
  local mod, _, state = fresh()
  mod.setup(mkopts())
  win(state, { pid = self_pid })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "after marker-env window opens")
end)

-- 3. An injected environ reader replaces the /proc read (test seam, and the
-- hook for exotic setups).
T("marker_env_via_injected_reader", function()
  local envs = { [GHOST_A] = "FOO=x\0DXVK_HDR=1\0" }
  local mod, _, state = fresh()
  mod.setup(mkopts({ environ_reader = function(pid) return envs[pid] end }))
  win(state, { pid = GHOST_A })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "after injected-marker window opens")
end)

-- 4. Sanity: last HDR window closing arms the cooldown, which reverts to SDR.
T("cooldown_reverts_after_close", function()
  local mod, _, state = fresh()
  mod.setup(mkopts())
  local w = win(state, { class = "gamescope" })
  MOCK.fire(state, "window.open")
  settle(state)
  remove_win(state, w)
  MOCK.fire(state, "window.close")
  settle(state)
  local cds = MOCK.timers_with_timeout(state, COOLDOWN_MS)
  assert(#cds >= 1, "no cooldown timer armed")
  MOCK.fire_timer(cds[#cds])
  eq(cm_of(MOCK.last_applied(state)), "srgb", "after cooldown fires")
end)

-- 5. The cooldown restarts from the LAST demand end: a window opening and
-- closing during a pending cooldown must arm a fresh full-length timer, and
-- the stale one must not revert early.
T("cooldown_restarts_when_burst_reopens", function()
  local mod, _, state = fresh()
  mod.setup(mkopts())
  local w1 = win(state, { class = "gamescope" })
  MOCK.fire(state, "window.open")
  settle(state)
  remove_win(state, w1)
  MOCK.fire(state, "window.close")
  settle(state)
  local w2 = win(state, { class = "gamescope" })
  MOCK.fire(state, "window.open")
  settle(state)
  remove_win(state, w2)
  MOCK.fire(state, "window.close")
  settle(state)
  local cds = MOCK.timers_with_timeout(state, COOLDOWN_MS)
  assert(#cds >= 2, "no fresh cooldown timer armed after the second close (got " .. #cds .. ")")
  MOCK.fire_timer(cds[1]) -- the stale timer from w1's close
  eq(cm_of(MOCK.last_applied(state)), "hdr", "stale cooldown timer must not revert")
  MOCK.fire_timer(cds[#cds])
  eq(cm_of(MOCK.last_applied(state)), "srgb", "fresh cooldown timer reverts")
end)

-- 6. A monitor re-added with no HDR demand gets the full SDR spec re-applied
-- (Hyprland just wiped bitdepth/vrr along with everything else).
T("sdr_reapplied_on_monitor_added_without_demand", function()
  local mod, _, state = fresh()
  mod.setup(mkopts())
  local before = #state.applied
  MOCK.fire(state, "monitor.added", { name = "DP-3" })
  settle(state)
  assert(#state.applied > before, "nothing re-applied on monitor.added")
  eq(cm_of(MOCK.last_applied(state)), "srgb", "re-applied spec")
end)

-- 7. An instance bound to a named output ignores another output's hotplug.
T("monitor_added_other_output_ignored", function()
  local mod, _, state = fresh()
  mod.setup(mkopts({ monitor = { output = "DP-3", mode = "preferred" } }))
  win(state, { class = "gamescope", output = "DP-3" })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "game running")
  local before = #state.applied
  MOCK.fire(state, "monitor.added", { name = "HDMI-A-1" })
  settle(state)
  eq(#state.applied, before, "apply count after unrelated hotplug")
end)

-- 8. The instance's own output coming back re-asserts HDR while a game lives.
T("monitor_added_own_output_reasserts_hdr", function()
  local mod, _, state = fresh()
  mod.setup(mkopts({ monitor = { output = "DP-3", mode = "preferred" } }))
  win(state, { class = "gamescope", output = "DP-3" })
  MOCK.fire(state, "window.open")
  settle(state)
  local before = #state.applied
  MOCK.fire(state, "monitor.added", { name = "DP-3" })
  settle(state)
  assert(#state.applied > before, "nothing re-applied on own monitor.added")
  eq(cm_of(MOCK.last_applied(state)), "hdr", "re-asserted spec")
end)

-- 9. Demand is scoped per output: a game on DP-3 must not flip DP-1.
T("demand_scoped_to_own_monitor", function()
  local envs = { [GHOST_A] = "DXVK_HDR=1\0" }
  local reader = function(pid) return envs[pid] end
  local mod, _, state = fresh()
  mod.setup(mkopts({ monitor = { output = "DP-1", mode = "preferred" }, environ_reader = reader }))
  mod.setup(mkopts({ monitor = { output = "DP-3", mode = "preferred" }, environ_reader = reader }))
  local before = #state.applied
  win(state, { pid = GHOST_A, output = "DP-3" })
  MOCK.fire(state, "window.open")
  settle(state)
  local flipped_dp1 = false
  local flipped_dp3 = false
  for i = before + 1, #state.applied do
    local s = state.applied[i]
    if s.cm == "hdr" and s.output == "DP-1" then flipped_dp1 = true end
    if s.cm == "hdr" and s.output == "DP-3" then flipped_dp3 = true end
  end
  eq(flipped_dp3, true, "DP-3 switched to HDR")
  eq(flipped_dp1, false, "DP-1 must stay SDR")
end)

-- 10. The per-PID env verdict dies with the window: after a marker window
-- closes, a recycled PID with a different environ is re-read, not served the
-- stale verdict.
T("env_cache_dropped_when_window_closes", function()
  local envs = { [GHOST_B] = "DXVK_HDR=1\0" }
  local mod, _, state = fresh()
  mod.setup(mkopts({ environ_reader = function(pid) return envs[pid] end }))
  local w = win(state, { pid = GHOST_B })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "marker window in HDR")
  remove_win(state, w)
  MOCK.fire(state, "window.close")
  settle(state)
  for _, t in ipairs(MOCK.timers_with_timeout(state, COOLDOWN_MS)) do MOCK.fire_timer(t) end
  eq(cm_of(MOCK.last_applied(state)), "srgb", "reverted after close")
  envs[GHOST_B] = "PLAIN=1\0" -- PID recycled by a non-HDR process
  win(state, { pid = GHOST_B })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "srgb", "recycled PID must not inherit the old verdict")
end)

-- 11. An unreadable environ is a transient condition, not a cached "no".
T("unreadable_environ_not_negative_cached", function()
  local envs = {}
  local mod, _, state = fresh()
  mod.setup(mkopts({ environ_reader = function(pid) return envs[pid] end }))
  win(state, { pid = GHOST_C })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "srgb", "unreadable environ stays SDR")
  envs[GHOST_C] = "DXVK_HDR=1\0" -- environ becomes readable (e.g. post-exec)
  win(state, { pid = GHOST_C })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "readable environ must be re-probed")
end)

-- 12. Sanity: prewarm enters HDR with no window and expires into the normal
-- cooldown revert.
T("prewarm_enters_hdr_and_expires", function()
  local mod, _, state = fresh()
  local h = mod.setup(mkopts())
  h.prewarm()
  eq(cm_of(MOCK.last_applied(state)), "hdr", "during prewarm hold")
  for _, t in ipairs(MOCK.timers_with_timeout(state, PREWARM_MS)) do MOCK.fire_timer(t) end
  settle(state)
  for _, t in ipairs(MOCK.timers_with_timeout(state, COOLDOWN_MS)) do MOCK.fire_timer(t) end
  eq(cm_of(MOCK.last_applied(state)), "srgb", "after hold and cooldown expire")
end)

-- 13. A prewarm hold survives the config reload that recreates the Lua VM
-- (Omarchy auto-reloads on every file save).
T("prewarm_hold_survives_reload", function()
  local mod, _, state = fresh()
  local h = mod.setup(mkopts())
  h.prewarm()
  eq(cm_of(MOCK.last_applied(state)), "hdr", "during prewarm hold")
  local mod2, _, state2 = fresh(true) -- new VM, persisted state kept
  mod2.setup(mkopts())
  eq(cm_of(MOCK.last_applied(state2)), "hdr", "baseline after mid-hold reload")
end)

-- 13b. The persisted deadline dies with the hold: once it expires and the
-- module reverts, a reload must not resurrect the hold from disk.
T("expired_hold_not_resumed_after_reload", function()
  local mod, _, state = fresh()
  local h = mod.setup(mkopts())
  h.prewarm()
  for _, t in ipairs(MOCK.timers_with_timeout(state, PREWARM_MS)) do MOCK.fire_timer(t) end
  settle(state)
  for _, t in ipairs(MOCK.timers_with_timeout(state, COOLDOWN_MS)) do MOCK.fire_timer(t) end
  eq(cm_of(MOCK.last_applied(state)), "srgb", "reverted after hold expiry")
  local mod2, _, state2 = fresh(true) -- reload with whatever state persisted
  mod2.setup(mkopts())
  eq(cm_of(MOCK.last_applied(state2)), "srgb", "expired hold must not resume after reload")
end)

-- 14. wants_hdr() reports real window demand, not a prewarm hold.
T("wants_hdr_excludes_prewarm", function()
  local mod, _, state = fresh()
  local h = mod.setup(mkopts())
  h.prewarm()
  eq(h.in_hdr(), true, "in_hdr during hold")
  eq(h.wants_hdr(), false, "wants_hdr during a windowless hold")
end)

-- 15. A missed close event is recovered by the periodic reconcile check.
T("reconcile_recovers_missed_close", function()
  local mod, _, state = fresh()
  win(state, { class = "gamescope" })
  mod.setup(mkopts())
  eq(cm_of(MOCK.last_applied(state)), "hdr", "adopted at startup")
  state.windows = {} -- window vanishes without any event
  local reps = {}
  for _, t in ipairs(state.timers) do
    if t.type == "repeat" then table.insert(reps, t) end
  end
  assert(#reps >= 1, "no reconcile timer registered")
  MOCK.fire_timer(reps[1])
  for _, t in ipairs(MOCK.timers_with_timeout(state, COOLDOWN_MS)) do MOCK.fire_timer(t) end
  eq(cm_of(MOCK.last_applied(state)), "srgb", "reconcile noticed the missing window")
end)

-- 16. A non-finite cooldown is rejected at setup, not turned into a wedged
-- timer later.
T("nonfinite_cooldown_rejected_at_setup", function()
  local mod = fresh()
  local ok = pcall(mod.setup, mkopts({ cooldown_sec = math.huge }))
  eq(ok, false, "setup(cooldown_sec=math.huge) must error")
end)

-- 17. A throwing hl.monitor must not latch state: the next event retries.
T("failed_hdr_apply_retries_on_next_event", function()
  local mod, _, state = fresh()
  local h = mod.setup(mkopts())
  state.monitor_error = "boom" -- next hl.monitor call throws once
  win(state, { class = "gamescope" })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(h.in_hdr(), false, "in_hdr after failed apply")
  win(state, { class = "gamescope" })
  MOCK.fire(state, "window.open")
  settle(state)
  eq(cm_of(MOCK.last_applied(state)), "hdr", "retried on next event")
  eq(h.in_hdr(), true, "in_hdr after successful retry")
end)

-- 18. A burst of window events coalesces into few full-window scans.
T("event_bursts_coalesce_window_scans", function()
  local mod, _, state = fresh()
  mod.setup(mkopts())
  state.gw_calls = 0
  for _ = 1, 5 do
    win(state, { class = "gamescope" })
    MOCK.fire(state, "window.open")
  end
  settle(state)
  assert(state.gw_calls <= 3,
    "5 rapid events caused " .. state.gw_calls .. " window scans (want <= 3)")
end)

print(string.format("%d passed, %d failed", passed, #failed))
for _, f in ipairs(failed) do print("FAIL " .. f) end
os.exit(#failed == 0 and 0 or 1)
