-- Offline prototype smoke test; state files live only in a temporary runtime.
package.path = "home/dot_config/?.lua;" .. package.path
local runtime = os.tmpname()
assert(os.remove(runtime))
assert(os.execute("mkdir -p " .. string.format("%q", runtime .. "/hypr/test")))
local getenv = os.getenv
os.getenv = function(key)
  if key == "XDG_RUNTIME_DIR" then return runtime end
  if key == "HYPRLAND_INSTANCE_SIGNATURE" then return "test" end
  return getenv(key)
end
local launch = require("hypr.launch_options")
local starts = { [10] = "100", [20] = "200" }
launch.process_start = function(pid) return starts[pid] end
launch.read = function(pid) return { hdr = pid == 30 } end
local monitor = { name = "HDMI-A-2", enabled = true, dpms_status = true, cm = "srgb" }
local other = { name = "DP-9", enabled = true, dpms_status = true, cm = "srgb" }
local stream = { name = "PF-1", enabled = true, dpms_status = true, cm = "srgb" }
local connected = { monitor, other, stream }
local windows, changes, events, tick = {}, {}, {}
hl = {
  get_windows = function() return windows end,
  get_monitors = function() return connected end,
  on = function(event, callback) events[event] = callback end,
  timer = function(callback) tick = callback end,
  monitor = function(rule)
    assert(rule.output == "HDMI-A-2" or rule.output == "DP-9", "touch only registered outputs")
    changes[#changes + 1] = rule
    for _, output in ipairs(connected) do
      if output.name == rule.output then output.cm = rule.cm end
    end
  end,
}
local function setup()
  return dofile("home/dot_config/hypr/hdr.lua").setup({
    { output = "HDMI-A-2", cm = "srgb" },
    { output = "DP-9", cm = "srgb" },
  })
end
local controller = setup()
controller.acquire(10)
assert(monitor.cm == "hdr" and other.cm == "hdr", "prepare every registered output before launch")
assert(stream.cm == "srgb", "leave unregistered stream output unchanged")
assert(controller.ready(), "readiness includes registered outputs only")
other.cm = "srgb"
assert(not controller.ready(), "wait until every awake registered output is HDR")
controller.reconcile()
assert(changes[#changes].mode == nil and changes[#changes].scale == nil,
  "runtime color updates must not overwrite geometry")
controller.acquire(20)
controller.release(10)
assert(monitor.cm == "hdr", "one exit must not reset another game's HDR")
monitor.cm = "srgb"
controller = setup()
events["config.reloaded"]()
assert(monitor.cm == "hdr", "reload must recover a live launch without windows")
monitor.dpms_status, monitor.cm = false, "srgb"
local before = #changes
tick()
assert(#changes == before, "never wake a sleeping monitor")
monitor.dpms_status = true
tick()
assert(monitor.cm == "hdr", "restore actual state after wake")
starts[20] = "201"
tick()
assert(monitor.cm == "srgb", "PID reuse must not retain stale ownership")
windows = { { pid = 30, mapped = true, monitor = monitor, workspace = { id = 6 } } }
events["window.open"]()
assert(monitor.cm == "hdr", "unwrapped marked local window opts in")
windows[1].monitor = { name = "PF-1" }
tick()
assert(monitor.cm == "srgb", "stream windows must not enable local HDR")
windows = {}
controller.acquire(10)
starts[10] = nil
tick()
assert(monitor.cm == "srgb", "dead launcher must release HDR without an exit hook")
monitor.name, monitor.cm = "UNREGISTERED-1", "srgb"
connected = { monitor, stream }
assert(not controller.ready(), "no registered output available")
starts[10] = "100"
before = #changes
controller.acquire(10)
assert(#changes == before, "do not touch unregistered outputs regardless of their name")
controller.release(10)
assert(not pcall(function()
  dofile("home/dot_config/hypr/hdr.lua").setup({ { output = "" } })
end), "reject a wildcard registration")
assert(not pcall(controller.acquire, 99), "reject missing processes")
assert(not events["window.fullscreen"], "tracker must not enforce fullscreen")
os.getenv = getenv
assert(os.remove(runtime .. "/hypr/test/hdr-launches"))
assert(os.remove(runtime .. "/hypr/test"))
assert(os.remove(runtime .. "/hypr"))
assert(os.remove(runtime))
print("HDR prototype: launch ownership, reload, wake, PID reuse, and stream isolation passed")
