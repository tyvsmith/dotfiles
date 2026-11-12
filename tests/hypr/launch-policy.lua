package.path = "home/dot_config/?.lua;" .. package.path
local starts, rules, events = {}, {}, {}
local hdr = { acquire = function() end, release = function() end, ready = function() end }
package.loaded["hypr.hdr"] = { setup = function(monitors)
  starts.hdr = (starts.hdr or 0) + 1
  assert(#monitors == 1 and monitors[1].output == "DP-1")
  return hdr
end }
package.loaded["hypr.dnd"] = { setup = function() starts.dnd = (starts.dnd or 0) + 1 end }
hl = {
  env = function() end, config = function() end,
  on = function(event, fn)
    assert(not events[event], "duplicate event handler: " .. event)
    events[event] = fn
  end,
  get_active_workspace = function() return { id = 1 } end,
  dispatch = function(action) rules[#rules + 1] = action end,
  dsp = { focus = function(action) return action end },
}
o = { window = function() end }
require("hypr.monitors")
require("hypr.windows")
assert(next(starts) == nil and next(events) == nil, "declarations must not start trackers")
local policy = require("hypr.launch_policy")
-- Exercise the real config entrypoint, stubbing only unrelated desktop setup.
for _, name in ipairs({ "default.hypr.omarchy", "default.hypr.toggles",
  "hypr.input", "hypr.bindings", "hypr.looknfeel", "hypr.autostart", "hypr.omacontrol" }) do
  package.loaded[name] = true
end
local load_file = dofile
dofile = function(path)
  if path:match("/default/hypr/bootstrap.lua$") then return end
  return load_file(path)
end
dofile("home/dot_config/hypr/hyprland.lua")
dofile = load_file
assert(launch_policy == policy, "publish the launcher interface")
policy.setup()
assert(starts.hdr == 1 and starts.dnd == 1, "initialize each tracker once")
assert(policy.hdr == hdr, "expose HDR readiness and ownership through the policy")
assert(events["window.open"], "initialize placement")
local options = require("hypr.launch_options")
options.read = function() return {} end
options.is_startup = function() return false end
events["window.open"]({ address = "0x123", class = "Beeper", pid = 123,
  workspace = { id = 4 }, floating = false })
assert(#rules == 1 and rules[1].window == "address:0x123", "preserve managed app declarations")
print("Launch policy: deferred initialization, idempotence, HDR interface, and window registration passed")
