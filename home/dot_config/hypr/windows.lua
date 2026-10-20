-- Personal rules, registered after Omarchy defaults. Later exceptions win.
local placement = require("hypr.placement")

-- Keep each destination here; autostart only supplies launch identity.
local function app(class, workspace, match)
  o.window(match or class:gsub("%.", "\\."), { workspace = workspace .. " silent" })
  placement.manage(class)
end

-- slack
app("com.slack.Slack", 4)

-- beeper
app("Beeper", 4)

-- vesktop
app("vesktop", 4)

-- steam
app("steam", 5, { class = "^steam$", title = "negative:^Steam Input On-screen Keyboard$" })

-- steamwebhelper
app("steamwebhelper", 5)

-- protonplus
app("com.vysp3r.ProtonPlus", 5)

-- Titled Steam windows tile; untitled popup menus retain the default float.
o.window({ class = "^steam$", title = "negative:^$" }, { tile = true })

-- Big Picture defaults to fullscreen for local and streamed sessions.
o.window({ class = "^steam$", title = "^Steam Big Picture Mode$" }, { fullscreen = true })

-- Undo tiling for notification overlays.
o.window({ class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" }, { float = true, no_initial_focus = true })

-- Keep the keyboard on the active workspace without initial focus.
o.window({ class = "^steam$", title = "^Steam Input On-screen Keyboard$" }, { float = true, no_initial_focus = true })

-- Keep popup menus focused while the pointer moves toward them.
o.window({ class = "^steam$", title = "^$" }, { min_size = { 1, 1 }, stay_focused = true })

-- streamcontroller
app("com.core447.StreamController", 10)

-- lan_mouse
app("de.feschber.LanMouse", 10)

-- battlenet
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, { tile = true })

-- Hide the empty GameGuard dialog without terminating its process.
o.window({ class = "^steam_app_553850$", initial_title = "^$" }, { no_focus = true, no_initial_focus = true, workspace = "special:hidden silent" })
