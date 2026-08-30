-- Extra autostart processes. Not o.exec_on_start: it cannot pass exec rules,
-- and o.launch_on_start would lose the `uwsm app -s a/-s b` slice assignments.

local apps      = require("hypr.apps")
local placement = require("hypr.placement")

local function exec_on_start(command, rules)
  hl.on("hyprland.start", function()
    hl.exec_cmd(command, rules)
  end)
end

-- Tray apps: parked on their workspace without stealing focus at boot. The
-- workspace comes from hypr/apps.lua, whose entries all set `silent`, so the
-- static rule already keeps boot quiet on its own. Launching one of these later
-- still takes you to it -- hypr/placement.lua focuses any window of theirs that
-- is not the boot one.
--
-- The exec rule below is a duplicate of that, kept because it costs nothing and
-- applies after the static rule when it does bind. It is NOT the mechanism: it
-- reaches only windows that kept HL_EXEC_RULE_TOKEN in their own environ or kept
-- the pid Hyprland forked, and it expires 60 s after spawn. Slack and
-- StreamController fail both tests, which is what used to yank focus at boot.
-- See hypr/apps.lua for the full account.
--
-- wait-for-sni blocks until a StatusNotifierWatcher is on the bus (10 s
-- fail-open). Still needed: the shell acquires the name after its bar maps,
-- and Chromium's tray code gives up for good if the watcher is absent at
-- init (Beeper, vesktop, Slack). StreamController self-heals from 1.5.0-beta.16;
-- Flathub ships beta.15.
local function tray_app_on_start(id, command)
  local app = apps.get(id)

  -- Runs at config load, so a `hyprctl reload` rebuilds the managed set. Arming
  -- is separate and happens once per session -- see hypr/placement.lua.
  placement.manage(apps.literal_class(app))

  exec_on_start("uwsm app -s b -- wait-for-sni " .. command,
    { workspace = apps.workspace_arg(app, true) })
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
