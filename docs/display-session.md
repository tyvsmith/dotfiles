# Display session model

How a game launched with `scb -- %command%` picks its display, compositor, and
HDR state. The mechanics are commented in `home/dot_config/scopebuddy/`.

## Launch matrix

Preferences (`local.conf` or `streaming.conf`: workspace and FPS margin) and
compositor ownership (`mode`) are decided independently at launch time:

| Launch | Preferences | Mode |
| --- | --- | --- |
| Local game on Hyprland | local | native |
| Local game wrapped in Gamescope | local | gamescope |
| Local Steam inside Gamescope | local | session |
| Native game on a Hyprland `PF-*` stream | streaming | native |
| Nested Gamescope on a Hyprland `PF-*` stream | streaming | gamescope |
| Punktfunk Steam inside Gamescope | streaming | session |

- `scb.conf` (and its `gamemode.conf` symlink) defaults to `mode=gamescope`,
  sources the first `games/*.conf` whose `APP_ID=$SCB_APPID` line matches, then
  applies the mode once. A game opts into `mode=native`; an existing Gamescope
  forces `session` either way.
- Session mode reuses Steam's compositor and installs no display hooks. HDR,
  HUD, resolution, and pacing stay with the outer session; Punktfunk sets
  `DXVK_HDR=1` for HDR streams and session mode never forces HDR on an SDR one.
- `fps_cap` is derived before the game file loads, so a game that changes
  `refresh` or `fps_margin` must set `fps_cap` itself. Unsetting a mode-owned
  flag requests its default; use `0` to disable it.

## Display snapshot

`display_init` runs once in ScopeBuddy's shell; the getters never query again.

- local Hyprland launch: the active LG `DP-1` mode
- Hyprland stream: the focused `PF-*` output, when Punktfunk reports an active
  session; a connected tablet alone does not redirect a local game
- inside Gamescope: the `*` mode from `xrandr --current`; missing metadata
  leaves the values unknown and session reuse still works
- a desktop launch aborts when its mode cannot be resolved

Pixel dimensions ignore desktop scale and refresh keeps its fraction.
`get_display_fps_cap` rounds it and subtracts the profile margin (local 4,
streaming 0); Gamescope's `-r` gets the rounded refresh.

## Local HDR lifecycle

- `hypr/monitors.lua` registers `DP-1` through `hypr/launch_policy.lua`; unregistered outputs
  are untouched
- `scb_display_start` registers ScopeBuddy's PID through `launch_policy.hdr.acquire`
  and waits for registered, awake outputs to enter HDR before starting the game
- `scb_display_stop` releases only that launch; other local launches retain HDR
- PID/start-time records in Hyprland's runtime directory survive reloads;
  dead owners are pruned and the final exit restores the SDR baseline
- window/monitor events and a one-second timer reconcile HDR after reload,
  reconnect, wake, or preset drift without waking sleeping outputs
- streamed launches do not acquire local HDR; `HYPR_HDR=0` opts out locally
- see `launch-policy-prototype.md` for verification and remaining limitations

## Punktfunk detection

- existing Gamescope: `XDG_CURRENT_DESKTOP=gamescope` or
  `GAMESCOPE_WAYLAND_DISPLAY`, not ScopeBuddy's global Steam-process heuristic
- streaming inside Gamescope: `LIBEI_SOCKET` equals the contents of
  `$XDG_RUNTIME_DIR/punktfunk-gamescope-ei` or `punktfunk-gamescope-*-ei`,
  which Punktfunk writes before starting Steam
  ([v0.46.0 source](https://git.unom.io/unom/punktfunk/src/tag/v0.46.0/crates/host/pf-vdisplay/src/vdisplay/linux/gamescope/spawn.rs));
  an unmatched relay keeps session mode with local preferences
- on Hyprland: `punktfunk-host ctl status --json` reports `active_sessions > 0`
  and the focused output is `PF-*`; an unavailable query falls back to local

## Window placement

Desktop modes export `HYPR_WORKSPACE=6` (local only), `HYPR_FULLSCREEN=1`,
and `HYPR_HDR=1` for local launches (`0` for streams).
`hypr/placement.lua` reads them from each new window's environment and moves
and fullscreens it once. These are personal markers, not ScopeBuddy or Hyprland
variables; `export HYPR_FULLSCREEN=0` in a game file opts out.
