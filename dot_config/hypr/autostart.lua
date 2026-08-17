-- Extra autostart processes.
--
-- These use o.exec_on_start rather than o.launch_on_start deliberately:
-- o.launch_on_start expands to `uwsm-app -- <cmd>`, which would drop the
-- `-s a` / `-s b` uwsm slice assignments the 3.x autostart.conf set.

-- Compositor plugins (hyprpm). Was `exec-once = hyprpm reload -n`.
o.exec_on_start("hyprpm reload -n")

o.exec_on_start("uwsm app -s a -- hypr-dock")

-- No hypr-sticky-hdr line: the HDR logic lives in hypr/sticky_hdr.lua, driven
-- by Hyprland's own window events. The old daemon is no longer installed; running
-- it as well would put two controllers on the same monitor, fighting over its mode.

-- wait-for-sni blocks until a StatusNotifierWatcher is on the bus so these
-- apps' tray icons actually register on cold boot. It waits on the generic
-- org.kde.StatusNotifierWatcher name with a 10-second fail-open, not on waybar
-- specifically, so Quickshell satisfies it the same way waybar did.
--
-- StreamController must be launched from here ONLY. It also writes its own
-- ~/.config/autostart/StreamController.desktop, and both launchers firing at
-- login raced its D-Bus single-instance check -- two instances would survive and
-- fight over the Stream Deck's exclusive USB claim, leaving the deck lit but
-- unresponsive with every window reporting "No streamdeck attached".
-- That second path stays dead via the systemd mask in
-- dot_config/systemd/user/symlink_app-StreamController@autostart.service --
-- deleting the .desktop is not enough, the app recreates it on every launch
-- (upstream bug: autostart.py's portal-failure fallback calls
-- setup_autostart_desktop_entry() with no args, defaulting to enable=True, so it
-- re-adds the entry even when autostart is set to false).
-- -b starts it to the tray instead of opening a window.
o.exec_on_start("uwsm app -s b -- wait-for-sni flatpak run com.core447.StreamController -b")
o.exec_on_start("uwsm app -s b -- wait-for-sni lan-mouse")
o.exec_on_start("uwsm app -s b -- wait-for-sni beeper")
o.exec_on_start("uwsm app -s b -- wait-for-sni vesktop")

-- slack is not installed on this machine (`command -v slack` finds nothing), so
-- this line would fail silently every login. Re-enable it if slack comes back.
-- o.exec_on_start("uwsm app -s b -- wait-for-sni slack")
