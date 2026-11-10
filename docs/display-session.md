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
- `fps_cap` defaults to rounded `refresh` minus `fps_margin` after the game
  file loads. A game can override any of these; `fps_cap=0` disables the
  external cap. Unsetting a mode-owned flag requests its default.

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
streaming 0). Nested Gamescope advertises the cap as its virtual refresh when
its limiter is selected; the physical display mode stays unchanged.

## HUD and FPS limits

`scb.conf` declares defaults; `common.sh` loads context/game overrides, derives
and validates the cap, selects the limiter, and builds the launch command.
Mode files retain compositor arguments and native-rendering defaults.

| Mode | HUD | Default limiter |
| --- | --- | --- |
| `gamescope` | Mangoapp | hidden MangoHud at `fps_cap` |
| `native` | MangoHud | MangoHud at `fps_cap` |
| `session` | outer Gamescope's Mangoapp | outer session |

- Edit appearance and hotkeys through GOverlay's `MangoHud.conf`. Both HUDs
  load it with `read_cfg`; launch configuration supplies the cap last.
  Leave the file's `fps_limit=0`. Existing `MANGOHUD_CONFIG` appearance
  overrides are retained; `MANGOHUD_FPS_LIMIT` is cleared in desktop modes.
  Gamescope receives an explicit `MANGOHUD_CONFIGFILE` so Steam mode cannot
  substitute its temporary hidden-HUD config; an explicit custom path wins.
- Mangoapp cannot limit the game. Its `fps_limit` is always zero. Nested
  launches use a hidden MangoHud layer for the cap, with HUD, preset, limiter,
  logging, and reload hotkeys disabled. Mangoapp remains the interactive HUD.
- `fps_limiter=gamescope` opts into `-r <cap> --framerate-limit <cap>`.
  Use it only with a build/backend whose cap you have verified. The installed
  Gamescope 3.17.0 exceeded 161 FPS in Hellraiser with Smooth Motion disabled;
  upstream's refresh-policy update can discard the CLI cap. Punktfunk patches
  that path and retains its own outer-session pacing.
- The default hidden limiter retains the display's rounded virtual refresh.
  `fps_cap=0` disables its cap; VSync or a game's own limit can still constrain FPS.
- A nonempty `SCB_GAMESCOPE_ARGS` is a complete override: it owns Mangoapp,
  virtual refresh, and Gamescope limiter arguments. ScopeBuddy does not amend it.
- `fps_limiter=game` delegates limiting to the game's settings. It disables
  ScopeBuddy's limiter but keeps the mode's HUD. Set the game's cap yourself.
- `fps_limiter=mangohud` explicitly selects the default. It requires game
  injection; for incompatible titles set `game_env MANGOHUD 0` and
  `fps_limiter=game`, then configure the cap in the game. Disabling injection
  without selecting another limiter warns in native mode and rejects nested
  launches. Under Gamescope, the opt-out does not hide Mangoapp.
- Mangoapp 0.8.4 sleeps 500 ms while hidden, so brief toggle presses can be
  missed ([upstream loop](https://github.com/flightlessmango/MangoHud/blob/v0.8.4/src/app/main.cpp)).
  Deliberate presses worked in the local test; holding the chord too
  long can retrigger it. This is independent of duplicate HUD injection.

Smooth Motion is opt-in; `scb.conf` retains a commented example. Enable it
with `game_env_default NVPRESENT_ENABLE_SMOOTH_MOTION 1` in a game profile
so only the game receives it. In the tested 2x path, `fps_cap=80` targets
about 160 presented FPS. For games with their own frame generation, test one
method at a time.
Do not infer base rendering FPS from a generated-frame or stream counter, or
automatically halve the limit without checking that title's presentation path.

Punktfunk finds `~/.local/share/overrides/bin/punktfunk-gamescope` through
its service PATH. The wrapper calls `/usr/bin/punktfunk-gamescope` directly,
passes capability probes through, and adds one Mangoapp without changing
Punktfunk's pacing or capture arguments. The overrides directory must precede
`/usr/bin` in the user-service PATH, as it does in this desktop session.
Other outer Gamescope launchers must add their own `--mangoapp`.
The adapter targets desktop Steam/`-gamepadui`; Steam `-steamos3` needs a
separate disposable HUD config because it can
[overwrite the configured file](https://github.com/ValveSoftware/gamescope/issues/1800).

References: [Gamescope options](https://github.com/ValveSoftware/gamescope/blob/3.17.0/src/main.cpp),
[MangoHud configuration](https://github.com/flightlessmango/MangoHud/blob/v0.8.4/README.md),
[Punktfunk binary selection](https://git.unom.io/unom/punktfunk/src/tag/v0.46.0/crates/host/pf-vdisplay/src/vdisplay/linux/gamescope/discovery.rs).

### Set game-only environment variables

Use these in `scb.conf` or a context/game profile:

```bash
game_env PROTON_DLSS_UPGRADE 1
game_env PROTON_LOG_DIR "$HOME/.cache/proton-logs"
game_env_default NVPRESENT_ENABLE_SMOOTH_MOTION 1
game_env VKD3D_CONFIG descriptor_heap
```

- `game_env NAME VALUE` sets or replaces a game-only assignment; later calls win
- `game_env_default NAME VALUE` keeps a registered value, otherwise uses an
  inherited shell value, otherwise uses the supplied default; explicit `0`
  and empty strings are preserved
- Registration removes the name's export attribute. `common.sh` quotes each
  assignment into one `env` argument after Gamescope's `--`, or before the
  direct command in native/session mode
- The environment covers the game launch chain, including performance wrappers,
  GOverlay, Steam's launch wrapper, Proton, and Wine. It does not retroactively
  change the already-running Steam client
- Plain `export NAME=value` reaches all later children of ScopeBuddy, including
  pre/post hooks, Gamescope, Mangoapp, and the game. Use it for settings that
  must reach the compositor; use the API for runtime settings that belong only
  to the game

| Settings | Scope | Reason |
| --- | --- | --- |
| `PROTON_*`, `VKD3D_*`, `DXVK_*`, `__NGX_*`, `WAYLANDDRV_*` | game-only | configure Proton, Wine, or the game's graphics translation |
| `NVPRESENT_ENABLE_SMOOTH_MOTION` | game-only | prevent compositor interpolation |
| `HYPR_WORKSPACE`, `HYPR_FULLSCREEN`, `HYPR_HDR`, `HYPR_DND` | exported launch markers | Hyprland observes Gamescope's process for nested windows and the game for direct windows |
| `MANGOHUD*` | mode-owned | Mangoapp needs compositor configuration; native/hidden MangoHud needs game configuration |

The active game-profile exports and dormant NGX/DLSS examples use this API.
For MangoHud compatibility opt-outs use `game_env MANGOHUD 0`; use `fps_cap`
and `fps_limiter` for pacing instead of overriding mode-owned HUD limit fields.
Use exported `MANGOHUD_CONFIG` and `MANGOHUD_CONFIGFILE` for compositor HUD
appearance. Nested/session policy owns game injection and can override queued
HUD settings; an existing session always disables the game's MangoHud layer.

### Try a branch without replacing the live ScopeBuddy config

From the repository root, create a temporary launch entry (Fish or Bash):

```sh
printf '%s\n' "SCB_CONFIGDIR='$PWD/home/dot_config/scopebuddy'" 'source "$SCB_CONFIGDIR/scb.conf"' > ~/.config/scopebuddy/hud-trial.conf
```

Use this Steam launch option for the first test:

```text
NVPRESENT_ENABLE_SMOOTH_MOTION=0 SCB_CONF=hud-trial.conf scb -- %command%
```

- Check one press of Right Shift+F12 hides the HUD and one brings it back
- Check rendered/presented FPS and frametimes with VSync off, then on
- To compare Smooth Motion, enable the commented game-only setting, remove
  the launch-time opt-out, and repeat; compare the counter stages
- For a direct trial, temporarily add `mode=native` to the branch's game
  profile; restore it afterward. Also test a `PF-*` nested launch
- Keep the default hidden limiter for the baseline; test `fps_limiter=gamescope`
  separately only when evaluating a fixed compositor build

Restore `scb -- %command%` to roll back the trial, then delete
`~/.config/scopebuddy/hud-trial.conf`. Running games keep their launch environment.

The outer Punktfunk integration requires installing the PATH override.
Review the targeted diff first, then apply only that file:

```sh
chezmoi --source "$PWD" diff ~/.local/share/overrides/bin/punktfunk-gamescope
chezmoi --source "$PWD" apply --include=files ~/.local/share/overrides/bin/punktfunk-gamescope
systemctl --user show-environment | rg '^PATH='
systemctl --user restart punktfunk-host
```

Confirm the overrides directory precedes `/usr/bin` in the service PATH.
Run the restart only after disconnecting streams. In streamed Steam, verify
one HUD is visible in the client capture and that client delivery stays at the
negotiated rate. ScopeBuddy's `session` mode must not create another compositor
or cap. To roll back, remove the new override and restart the service.
Keep any pre-existing override backed up instead of overwriting it.
Applying the branch's ScopeBuddy config later is a separate
`chezmoi apply --include=files --recursive ~/.config/scopebuddy` step.

If you applied an earlier revision of this branch, remove its
`~/.config/systemd/user/punktfunk-host.service.d/hud.conf` and
`~/.local/bin/punktfunk-gamescope-hud`, then run `systemctl --user daemon-reload`
before restarting. That old binary override takes precedence over PATH.

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
