-- Personal window rules. Loaded after default.hypr.windows, so these win.
--
-- Workspace rules here are NOT silent on purpose: a launcher start or a tray
-- re-show should switch to the app. Boot launches stay quiet via the exec rule
-- in hypr/autostart.lua, which reads `placements` below and adds "silent".

local M = {}

-- Windows parked on a workspace, by short name. `match` is what o.window takes:
-- a string is a class regex (backslashes doubled, once for Lua and once for the
-- regex), a table matches any window property.
M.placements = {
  -- Workspace 4 -- messaging
  slack   = { match = "com\\.slack\\.Slack", workspace = 4 },
  beeper  = { match = "Beeper",             workspace = 4 },
  vesktop = { match = "vesktop",            workspace = 4 },

  -- Workspace 5 -- Steam
  steam          = { match = "steam",          workspace = 5 },
  steamwebhelper = { match = "steamwebhelper", workspace = 5 },
  protonplus     = { match = "protonplus",     workspace = 5 },

  -- Workspace 6 -- fullscreen/borderless games
  steam_games = { match = "steam_app_.*",       workspace = 6 },
  fullscreen  = { match = { fullscreen = 1 },   workspace = 6 },

  -- Workspace 10 -- utilities
  streamcontroller = { match = "com\\.core447\\.StreamController", workspace = 10 },
  lan_mouse        = { match = "de\\.feschber\\.LanMouse",         workspace = 10 },
}

for _, p in pairs(M.placements) do
  o.window(p.match, { workspace = tostring(p.workspace) })
end

return M
