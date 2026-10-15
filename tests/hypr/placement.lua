-- Run from the repository root: lua tests/hypr/placement.lua
local path = "home/dot_config/hypr/placement.lua"
local real_open = io.open
local events, actions, reads, blob, active = {}, {}, 0, nil, 1
local proc = {}
local function record(kind, spec) return { kind = kind, spec = spec } end
hl = {
  on = function(event, callback)
    events[event] = callback
    return { remove = function() events[event] = nil end }
  end,
  timer = function(callback) callback() end,
  get_active_workspace = function() return { id = active } end,
  dispatch = function(action) actions[#actions + 1] = action end,
  dsp = {
    window = { move = function(spec) return record("move", spec) end },
    focus = function(spec) return record("focus", spec) end,
  },
}
io.open = function(file, mode)
  if file == "/proc/123/environ" then
    reads = reads + 1
    if not blob then return nil end
    return { read = function() return blob end, close = function() end }
  end
  local content = proc[file]
  if content then return { read = function() return content end, close = function() end } end
  if file:match("^/proc/") then return nil end
  return real_open(file, mode)
end
local module = dofile(path)
assert(reads == 0 and #actions == 0, "loading must not inspect or move existing windows")
assert(events["window.open"] and not events["window.title"], "only handle new windows")
local function open(env, workspace, address)
  blob, actions = env, {}
  events["window.open"]({ pid = 123, address = address or "0xabc",
    workspace = workspace or { id = 1, name = "1" } })
end
open("OTHER=1\0HYPR_WORKSPACE=6\0")
assert(#actions == 1 and actions[1].kind == "move")
assert(actions[1].spec.window == "address:0xabc", "must target the new window")
assert(actions[1].spec.workspace == "6" and actions[1].spec.follow == true)
for _, env in ipairs({ "", "OTHER_HYPR_WORKSPACE=6\0", "X=HYPR_WORKSPACE=6\0",
  "HYPR_GAME_WORKSPACE=6\0", "HYPR_WORKSPACE=0\0", "HYPR_WORKSPACE=-1\0",
  "HYPR_WORKSPACE=6;bad\0", "HYPR_WORKSPACE=special:hidden\0",
  "HYPR_WORKSPACE=9999999999999999999999\0" }) do
  open(env)
  assert(#actions == 0, "invalid or unrelated marker must be ignored: " .. env)
end
open(nil)
assert(#actions == 0, "unreadable process must be ignored")
open("HYPR_WORKSPACE=7\0")
assert(actions[1].spec.workspace == "7", "do not cache missing markers or recycled PIDs")
open("HYPR_WORKSPACE=6\0", { id = -99, name = "special:hidden" })
assert(#actions == 0, "preserve the GameGuard special workspace rule")
open("HYPR_WORKSPACE=6\0", { id = 6, name = "6" })
assert(#actions == 1 and actions[1].kind == "focus", "follow even if a static rule already placed it")
active = 6
open("HYPR_WORKSPACE=6\0", { id = 6, name = "6" })
assert(#actions == 0, "do not warp the pointer on the current workspace")
active = 1
open("HYPR_WORKSPACE=6 silent\0")
assert(#actions == 1 and actions[1].spec.follow == false, "support silent placement")
open("HYPR_WORKSPACE=6 silent\0", { id = 6, name = "6" })
assert(#actions == 0, "silent placement must not focus an already placed window")
actions = {}
events["window.open"](nil)
events["window.open"]({ pid = 123, workspace = { id = 1 } })
assert(#actions == 0, "missing window identity must never target the active window")

-- Dynamic placement takes priority over managed-app focus, including silent launches.
module.manage("test-app")
blob, actions = "HYPR_WORKSPACE=7 silent\0", {}
events["window.open"]({ pid = 123, address = "0xdef", class = "test-app",
  workspace = { id = 4, name = "4" }, floating = false })
assert(#actions == 1 and actions[1].kind == "move" and actions[1].spec.follow == false)
assert(actions[1].spec.workspace == "7", "dynamic destination must override managed-app focus")

-- Startup identity survives delayed windows and module reloads.
local function managed_open(env)
  blob, actions = env, {}
  events["window.open"]({ pid = 123, address = "0xdef", class = "test-app",
    workspace = { id = 4, name = "4" }, floating = false })
end
managed_open("HYPR_AUTOSTART=1\0")
assert(#actions == 0, "startup must never force focus")
module = dofile(path)
module.manage("test-app")
managed_open("HYPR_AUTOSTART=1\0")
assert(#actions == 0, "startup stays silent after reload")
managed_open("OTHER=1\0")
assert(#actions == 1 and actions[1].kind == "focus", "manual launch follows")
managed_open(nil)
assert(#actions == 0, "unknown launch identity must fail silent")

proc["/proc/123/cgroup"] = "0::/user.slice/app-hypr-autostart-2.scope\n"
managed_open("OTHER=1\0")
assert(#actions == 0, "scope preserves startup identity after environ rewriting")
proc["/proc/123/cgroup"] = "0::/user.slice/app-other.scope\n"
proc["/proc/123/status"] = "Name:\tchild\nPPid:\t456\n"
proc["/proc/456/environ"] = "HYPR_AUTOSTART=1\0"
managed_open("OTHER=1\0")
assert(#actions == 0, "startup ancestor survives a sandbox scope change")
proc = {}
managed_open("OTHER_HYPR_AUTOSTART=1\0")
assert(#actions == 1, "match only the exact startup variable")
blob, actions = "OTHER=1\0", {}
events["window.open"]({ pid = 123, address = "0xdef", class = "test-app",
  workspace = { id = 4 }, floating = true })
assert(#actions == 0, "overlays must not trigger workspace focus")
assert(not events["hyprland.start"], "focus handling must not depend on session timing")

io.open = real_open
print("dynamic placement: all behavior checks passed")
