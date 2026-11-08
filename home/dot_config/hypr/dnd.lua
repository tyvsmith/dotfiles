-- Focus owns automatic DND; no manual state is saved or restored.
local launch = require("hypr.launch_options")
local M = {}

local function wanted()
  local window = hl.get_active_window()
  if not window or not window.mapped or window.hidden then return false end
  local monitor, workspace = window.monitor, window.workspace
  if not monitor or not monitor.enabled or not monitor.dpms_status
    or monitor.name:match("^PF%-") or not workspace then return false end
  local visible = monitor.active_special_workspace or monitor.active_workspace
  if not visible or visible.id ~= workspace.id then return false end
  local options = launch.read(window.pid)
  if not options or not options.dnd then return false end
  if (window.fullscreen & 2) ~= 0 then return true end

  -- Monitor mode uses logical, transformed dimensions, matching window geometry.
  local at, size, origin, mode = window.at, window.size, monitor.position, monitor.mode
  return math.abs(at.x - origin.x) <= 2 and math.abs(at.y - origin.y) <= 2
    and math.abs(size.x - mode.width) <= 2 and math.abs(size.y - mode.height) <= 2
end

function M.setup()
  local previous
  local function reconcile()
    local enabled = wanted()
    if enabled == previous then return end
    hl.exec_cmd("omarchy-shell notifications setDnd " .. (enabled and "on" or "off"))
    previous = enabled
  end
  for _, event in ipairs({ "config.reloaded", "window.active", "window.fullscreen",
    "window.destroy", "window.move_to_workspace", "workspace.active",
    "workspace.special_active", "monitor.focused" }) do
    hl.on(event, reconcile)
  end
  -- Geometry and DPMS changes have no dedicated window event; also settle focus transitions.
  hl.timer(reconcile, { timeout = 250, type = "repeat" })
end

return M
