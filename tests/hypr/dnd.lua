package.path = "home/dot_config/?.lua;" .. package.path
local opted = true
package.loaded["hypr.launch_options"] = { read = function() return { dnd = opted } end }
local monitor = { name = "DP-1", enabled = true, dpms_status = true,
  position = { x = 100, y = 0 }, mode = { width = 1280, height = 720 },
  active_workspace = { id = 6 } }
local game = { pid = 42, mapped = true, hidden = false, fullscreen = 2,
  monitor = monitor, workspace = { id = 6 }, at = { x = 100, y = 0 },
  size = { x = 1280, y = 720 } }
local active, commands, events, poll = nil, {}, {}
hl = {
  get_active_window = function() return active end,
  exec_cmd = function(command) commands[#commands + 1] = command end,
  on = function(event, fn) events[event] = fn end,
  timer = function(fn) poll = fn end,
}
local dnd = require("hypr.dnd")
dnd.setup()
local function expect(value)
  poll()
  assert(commands[#commands] == "omarchy-shell notifications setDnd " .. value)
end
expect("off")
active = game
expect("on")
local count = #commands
poll()
assert(#commands == count, "do not spawn commands for unchanged state")
active = nil
events["window.active"]()
expect("off")
active = game
expect("on")
monitor.active_workspace.id = 7
expect("off")
monitor.active_workspace.id = 6
opted = false
expect("off")
opted = true
monitor.name = "PF-test"
expect("off")
monitor.name = "DP-1"
game.fullscreen = 0
expect("on") -- borderless at logical monitor bounds
game.size.x = 1000
expect("off")
game.fullscreen = 1
expect("off") -- maximized is not necessarily screen-filling
game.fullscreen = 0
monitor.mode = { width = 720, height = 1280 } -- rotated/scaled logical bounds
game.size = { x = 720, y = 1280 }
expect("on")
game.at.x = 110
expect("off")
game.at.x = 100
game.hidden = true
expect("off")
game.hidden = false
monitor.dpms_status = false
expect("off")
monitor.dpms_status = true
monitor.active_special_workspace = { id = -2 }
expect("off")
monitor.active_special_workspace = nil
expect("on")
game.mapped = false
expect("off")
print("DND: focus, workspace, fullscreen, borderless geometry, opt-out, and streaming checks passed")
