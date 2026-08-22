-- Extra autostart processes. hl.exec_cmd rather than o.launch_on_start so the
-- `uwsm app -s a/-s b` slice assignments survive.

o.exec_on_start("hyprpm reload -n")

o.exec_on_start("uwsm app -s a -- hypr-dock")

-- No hypr-sticky-hdr: HDR lives in hypr/sticky_hdr.lua; the daemon would fight it.

-- Tray apps: parked on their workspace without stealing focus at boot. The rule
-- rides on the exec (Hyprland tags the process with HL_EXEC_RULE_TOKEN and
-- matches the window through its environ, so it survives uwsm/wait-for-sni),
-- and beats the static rule in hypr/windows.lua, which stays non-silent so a
-- launcher start or a tray re-show switches there. Exec rules expire 60 s after
-- spawn; a window that maps later falls through to the static rule.
--
-- wait-for-sni blocks until a StatusNotifierWatcher is on the bus so tray icons
-- register on cold boot (10 s fail-open).
local function tray_app_on_start(command, workspace)
  hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -s b -- wait-for-sni " .. command, { workspace = workspace .. " silent" })
  end)
end

-- Workspace 4 -- messaging
tray_app_on_start("beeper", 4)
tray_app_on_start("vesktop", 4)
tray_app_on_start("flatpak run com.slack.Slack -b", 4)

-- Workspace 5 -- Steam
tray_app_on_start("steam", 5)
tray_app_on_start("protonplus", 5)

-- Workspace 10 -- utilities
-- StreamController launches from here ONLY: its own autostart .desktop raced this
-- and two instances fought over the Stream Deck's USB claim. That path is masked
-- via systemd/user/app-StreamController@autostart.service; the app recreates the
-- .desktop on every launch, so deleting it is not enough. -b starts to the tray.
tray_app_on_start("flatpak run com.core447.StreamController -b", 10)
tray_app_on_start("lan-mouse", 10)
