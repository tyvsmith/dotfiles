-- Personal window rules.
--
-- Loaded after default.hypr.windows, so these win. Omarchy's own rules
-- (suppress_event maximize, the default-opacity tagging, the XWayland
-- drag fix) are already applied and are not restated here.
--
-- Syntax: o.window(match, rules). A string match is shorthand for class;
-- anything else needs a table. See $OMARCHY_PATH/default/hypr/windows.lua.

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

-- Workspace 10 -- utilities
-- Backslashes are doubled: Lua string escape, then the regex.
o.window("com\\.core447\\.StreamController", { workspace = "10 silent" })

-- Dropped in the Lua port: de\.feschber\.LanMouse -- lan-mouse was swapped for
-- deskflow in 90bbad5, so the rule matched nothing.
