-- Static app rules place silently; only explicit manual launches follow.
-- HYPR_WORKSPACE and HYPR_FULLSCREEN control explicit launches. Startup identity has no timeout.
local M = {}
local managed = {}

function M.manage(class)
  assert(type(class) == "string" and class ~= "")
  managed[class] = true
end

local launch = require("hypr.launch_options")

-- Return true when dynamic placement owns this event, including silent no-ops.
function M.place_from_env(window)
  if not window or not window.address or not window.workspace then return false end
  local workspace = window.workspace
  if (workspace.id and workspace.id < 0)
    or (workspace.name and workspace.name:match("^special:")) then return true end

  local options = launch.read(window.pid) or {}
  local target, follow, fullscreen = options.workspace, options.follow, options.fullscreen
  if not target and not fullscreen then return false end
  local selector = "address:" .. window.address
  if target and workspace.id ~= tonumber(target) then
    hl.dispatch(hl.dsp.window.move({
      window = selector, workspace = target, follow = follow,
    }))
  elseif target and follow then
    local active = hl.get_active_workspace()
    if active and active.id ~= tonumber(target) then
      hl.dispatch(hl.dsp.focus({ window = selector }))
    end
  end
  if fullscreen then
    hl.dispatch(hl.dsp.window.fullscreen({ window = selector, action = "set" }))
  end
  return true
end

function M.setup()
  hl.on("window.open", function(w)
    if not w or not w.address or not w.workspace then return end
    if M.place_from_env(w) then return end
    if not managed[w.class] or w.floating then return end
    local active = hl.get_active_workspace()
    if not active or w.workspace.id == active.id then return end
    if launch.is_startup(w.pid) ~= false then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
  end)
end

return M
