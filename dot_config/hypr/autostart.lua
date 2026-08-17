-- Extra autostart processes. o.exec_on_start rather than o.launch_on_start so
-- the `uwsm app -s a/-s b` slice assignments survive.

o.exec_on_start("hyprpm reload -n")

o.exec_on_start("uwsm app -s a -- hypr-dock")

-- No hypr-sticky-hdr: HDR lives in hypr/sticky_hdr.lua; the daemon would fight it.

-- wait-for-sni blocks until a StatusNotifierWatcher is on the bus so tray icons
-- register on cold boot (10 s fail-open).
-- StreamController launches from here ONLY: its own autostart .desktop raced this
-- and two instances fought over the Stream Deck's USB claim. That path is masked
-- via systemd/user/app-StreamController@autostart.service; the app recreates the
-- .desktop on every launch, so deleting it is not enough. -b starts to the tray.
o.exec_on_start("uwsm app -s b -- wait-for-sni flatpak run com.core447.StreamController -b")
o.exec_on_start("uwsm app -s b -- wait-for-sni lan-mouse")
o.exec_on_start("uwsm app -s b -- wait-for-sni beeper")
o.exec_on_start("uwsm app -s b -- wait-for-sni vesktop")
-- o.exec_on_start("uwsm app -s b -- wait-for-sni slack") -- not installed
