-- Windows parked on a workspace, by short name. Data only: hypr/windows.lua
-- registers the rules, hypr/autostart.lua adds "silent" for boot launches.
--
-- `match` is what o.window takes: a string is a class regex (backslashes
-- doubled, once for Lua and once for the regex), a table matches any window
-- property.
return {
  -- Workspace 4 -- messaging
  slack   = { match = "com\\.slack\\.Slack", workspace = 4 },
  beeper  = { match = "Beeper",             workspace = 4 },
  vesktop = { match = "vesktop",            workspace = 4 },

  -- Workspace 5 -- Steam
  steam          = { match = "steam",          workspace = 5 },
  steamwebhelper = { match = "steamwebhelper", workspace = 5 },
  protonplus     = { match = "protonplus",     workspace = 5 },

  -- Workspace 6 -- fullscreen/borderless games
  steam_games = { match = "steam_app_.*",     workspace = 6 },
  fullscreen  = { match = { fullscreen = 1 }, workspace = 6 },

  -- Workspace 10 -- utilities
  streamcontroller = { match = "com\\.core447\\.StreamController", workspace = 10 },
  lan_mouse        = { match = "de\\.feschber\\.LanMouse",         workspace = 10 },
}
