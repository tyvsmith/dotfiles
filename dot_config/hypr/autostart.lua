-- Extra autostart processes. Not o.exec_on_start: it cannot pass exec rules,
-- and o.launch_on_start would lose the `uwsm app -s a/-s b` slice assignments.

local window_workspaces = require("hypr.window_workspaces")

local function exec_on_start(command, rules)
  hl.on("hyprland.start", function()
    hl.exec_cmd(command, rules)
  end)
end

-- Tray apps: parked on their workspace without stealing focus at boot. The
-- workspace comes from hypr/window_workspaces.lua; only "silent" is added, as
-- an exec rule (Hyprland tags the process with HL_EXEC_RULE_TOKEN and matches the
-- window through its environ, so it survives uwsm/wait-for-sni) that beats the
-- static rule. Exec rules expire 60 s after spawn; a window that maps later
-- falls through to the static rule and switches workspace.
--
-- wait-for-sni blocks until a StatusNotifierWatcher is on the bus (10 s
-- fail-open). Still needed: the shell acquires the name after its bar maps,
-- and Chromium's tray code gives up for good if the watcher is absent at
-- init (Beeper, vesktop, Slack). StreamController self-heals from 1.5.0-beta.16;
-- Flathub ships beta.15.
local function tray_app_on_start(name, command)
  local p = assert(window_workspaces[name], "autostart: " .. name .. " has no entry in hypr/window_workspaces.lua")
  exec_on_start("uwsm app -s b -- wait-for-sni " .. command, { workspace = p.workspace .. " silent" })
end

exec_on_start("hyprpm reload -n")

exec_on_start("uwsm app -s a -- hypr-dock")

-- No hypr-sticky-hdr: HDR lives in hypr/sticky_hdr.lua; the daemon would fight it.

tray_app_on_start("beeper", "beeper")
tray_app_on_start("vesktop", "vesktop")
tray_app_on_start("slack", "flatpak run com.slack.Slack -b")
tray_app_on_start("steam", "steam")
tray_app_on_start("protonplus", "protonplus")
-- StreamController launches from here ONLY: its own autostart .desktop raced this
-- and two instances fought over the Stream Deck's USB claim. That path is masked
-- via systemd/user/app-StreamController@autostart.service; the app recreates the
-- .desktop on every launch, so deleting it is not enough. -b starts to the tray.
tray_app_on_start("streamcontroller", "flatpak run com.core447.StreamController -b")
tray_app_on_start("lan_mouse", "lan-mouse")
