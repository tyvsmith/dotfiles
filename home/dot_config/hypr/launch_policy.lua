-- Declarations collect here; hyprland.lua starts the policies after configuration.
local placement = require("hypr.placement")
local monitors, started = {}, false
local M = {}

function M.register_monitor(rule)
  assert(not started, "register monitors before starting launch policies")
  monitors[#monitors + 1] = rule
end

M.manage_window = placement.manage

function M.setup()
  if started then return M end
  M.hdr = require("hypr.hdr").setup(monitors)
  placement.setup()
  require("hypr.dnd").setup()
  started = true
  return M
end

return M
