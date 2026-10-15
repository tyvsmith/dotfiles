-- Commands only; workspace destinations live in windows.lua.
local function exec_on_start(command)
  hl.on("hyprland.start", function() hl.exec_cmd(command) end)
end

local startup_id = 0
local function tray_app_on_start(command)
  startup_id = startup_id + 1
  -- Scope identity survives applications rewriting their process environment.
  -- Keep the marker inside this launch, never in the session environment.
  exec_on_start("uwsm app -s b -t scope -u app-hypr-autostart-" .. startup_id
    .. ".scope -- env HYPR_AUTOSTART=1 wait-for-sni " .. command)
end

exec_on_start("hyprpm reload -n")
exec_on_start("uwsm app -s a -- hypr-dock")

-- Wait for the tray watcher before Chromium initializes its tray integration.
tray_app_on_start("beeper")
tray_app_on_start("vesktop")
tray_app_on_start("flatpak run com.slack.Slack -b")
-- tray_app_on_start("steam")
tray_app_on_start("protonplus")
-- Its desktop autostart remains masked to prevent duplicate USB claims.
tray_app_on_start("flatpak run com.core447.StreamController -b")
tray_app_on_start("lan-mouse")
