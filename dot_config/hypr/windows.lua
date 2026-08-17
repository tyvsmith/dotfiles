-- Personal window rules. Loaded after default.hypr.windows, so these win.
-- o.window(match, rules): a string match is shorthand for class.

-- Workspace 4 -- messaging
o.window("Slack", { workspace = "4 silent" })
o.window("BeeperTexts", { workspace = "4 silent" })
o.window("vesktop", { workspace = "4 silent" })

-- Workspace 5 -- Steam
o.window("steam", { workspace = "5 silent" })
o.window("steamwebhelper", { workspace = "5 silent" })

-- Workspace 6 -- fullscreen/borderless games
o.window({ fullscreen = 1 }, { workspace = "6 silent" })
o.window("steam_app_.*", { workspace = "6 silent" })

-- Workspace 10 -- utilities (backslashes doubled: Lua escape, then regex)
o.window("com\\.core447\\.StreamController", { workspace = "10 silent" })
o.window("de\\.feschber\\.LanMouse", { workspace = "10 silent" })
