-- Personal window rules. Loaded after default.hypr.windows, so these win.
-- o.window(match, rules): a string match is shorthand for class.
--
-- Workspace rules here are NOT silent on purpose: a launcher start or a tray
-- re-show should switch to the app. Boot launches stay quiet via the exec rule
-- in hypr/autostart.lua, which overrides these.

-- Workspace 4 -- messaging
o.window("com\\.slack\\.Slack", { workspace = "4" })
o.window("Beeper", { workspace = "4" })
o.window("vesktop", { workspace = "4" })

-- Workspace 5 -- Steam
o.window("steam", { workspace = "5" })
o.window("steamwebhelper", { workspace = "5" })
o.window("protonplus", { workspace = "5" })

-- Workspace 6 -- fullscreen/borderless games (silent: a game launching from
-- Steam should not yank focus while it loads)
o.window({ fullscreen = 1 }, { workspace = "6 silent" })
o.window("steam_app_.*", { workspace = "6 silent" })

-- Workspace 10 -- utilities (backslashes doubled: Lua escape, then regex)
o.window("com\\.core447\\.StreamController", { workspace = "10" })
o.window("de\\.feschber\\.LanMouse", { workspace = "10" })
