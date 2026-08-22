-- Personal window rules. Loaded after default.hypr.windows, so these win.
-- o.window(match, rules): a string match is shorthand for class.
--
-- Workspace rules here are NOT silent on purpose: a launcher start or a tray
-- re-show should switch to the app. Boot launches stay quiet via the exec rule
-- in hypr/autostart.lua, which reads `apps` below and adds "silent" on top.

local M = {}

-- Apps parked on a workspace, by short name (class is a regex: backslashes are
-- doubled, once for Lua and once for the regex).
M.apps = {
  -- Workspace 4 -- messaging
  slack   = { class = "com\\.slack\\.Slack", workspace = 4 },
  beeper  = { class = "Beeper",             workspace = 4 },
  vesktop = { class = "vesktop",            workspace = 4 },

  -- Workspace 5 -- Steam
  steam          = { class = "steam",          workspace = 5 },
  steamwebhelper = { class = "steamwebhelper", workspace = 5 },
  protonplus     = { class = "protonplus",     workspace = 5 },

  -- Workspace 10 -- utilities
  streamcontroller = { class = "com\\.core447\\.StreamController", workspace = 10 },
  lan_mouse        = { class = "de\\.feschber\\.LanMouse",         workspace = 10 },
}

for _, app in pairs(M.apps) do
  o.window(app.class, { workspace = tostring(app.workspace) })
end

-- Workspace 6 -- fullscreen/borderless games
o.window({ fullscreen = 1 }, { workspace = "6" })
o.window("steam_app_.*", { workspace = "6" })

return M
