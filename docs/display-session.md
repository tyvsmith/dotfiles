# Display control

- keep DP-1 in SDR for the desktop, with 10-bit color, fullscreen VRR, and SDR brightness 1.35
- use `scb -- %command%` for games; native launches enable LG HDR before Wine probes, Gamescope launches do so before the compositor starts
- restore LG SDR through ScopeBuddy's exit hook; preserve its current resolution, position, scale, and transform in both directions
- leave Punktfunk output creation, connection lifetime, placement, and negotiated SDR/HDR mode to Punktfunk
- retire hyprmoncfg, its profile wrapper, and automatic sticky-HDR detection

## ScopeBuddy configuration

- `scb.conf`: user defaults, local workspace 6 versus the stream workspace, fullscreen, frame cap, performance wrappers, and default mode
- `lib/display.sh`: sourced functions that share cleanup state with ScopeBuddy's exit hook
- `modes/native.conf` and `modes/gamescope.conf`: rendering flags and the launch sequence for each mode

The display helper exposes three lifecycle functions:

| Function | Responsibility |
| --- | --- |
| `scb_display_init` | snapshot the launch target and stream dimensions; initialize cleanup ownership without changing a monitor |
| `scb_display_start` | prepare that target and wait for HDR readiness before launch |
| `scb_display_stop` | restore LG SDR only if this launch enabled HDR |

ScopeBuddy skips its pre-command hook in native mode, so the native command uses
`scb_display_start && game`. Gamescope uses `scb_display_start || exit 1` in its
pre-hook because ScopeBuddy otherwise continues after a failure. Both modes use
the same exit hook. Source the helper in the runner's shell; separate executable
hooks would lose its in-memory cleanup state.

### Per-game overrides

`AppID/<appid>.conf` loads after these defaults. Select `mode native` or
`mode gamescope` first, then apply overrides. Each mode rebuilds the command from
the original game command, so switching modes does not stack wrappers.

```bash
unset PROTON_ENABLE_WAYLAND  # opt out of Wine-Wayland in native mode
unset DXVK_HDR              # opt out of native game HDR; LG still enters HDR
unset HYPR_FULLSCREEN       # opt out of the Hyprland fullscreen rule
unset PROTON_DLSS_UPGRADE   # keep the shipped DLSS library
export MANGOHUD=0           # disable the native HUD
```

Gamescope's own fullscreen/HDR flags remain independent. To drop the performance
wrappers while preserving display preparation, set
`command="scb_display_start && $game_command"` in native mode or
`command="$game_command"` in Gamescope mode. Append game arguments after the mode
selection. Avoid shell compounds in the Gamescope command: ScopeBuddy embeds it
inside Gamescope's argument list.

`game-performance` handles the idle/power hold; `gamemoderun` activates GameMode.
In Gamescope mode, mangoapp draws the HUD and the hidden in-game MangoHud layer
provides the exact FPS cap. Set `SCB_DEBUG=1` to log the expanded launch command.

## Local HDR

`monitors.lua` supplies the SDR baseline and `lg_hdr(enabled)`. This function only
changes an active DP-1. It never enables a disabled LG or changes a virtual output.
There are no window listeners, polling timers, or monitor-profile daemons.

Manual controls:

```sh
hyprctl eval 'lg_hdr(true)'   # HDR on
hyprctl eval 'lg_hdr(false)'  # SDR / recovery after killing ScopeBuddy
```

Use one local SCB game at a time. The first game to exit restores SDR even if a
second game is running. Ordinary game exits/crashes reach SCB's exit hook;
`SIGKILL` of SCB, compositor failure, or a failed cleanup command cannot guarantee
restoration. A config reload restores the SDR baseline, including during a game.
Games launched without SCB need the manual commands. The monitor being in HDR does
not make an SDR game render HDR.

## Game window placement

ScopeBuddy exports `HYPR_WORKSPACE=6` for local games and removes it for streams.
`hypr/placement.lua` reads this marker from each new window's process environment
and moves it to the requested workspace. This is a personal integration, not a
built-in ScopeBuddy or Hyprland variable.

ScopeBuddy also exports `HYPR_FULLSCREEN=1` for both paths. The same handler sets
fullscreen after placement, or on the existing workspace for streams. It runs
once when each window opens; subsequent fullscreen toggles remain available.
Hidden anti-cheat windows retain their special-workspace exception. Other windows
inheriting the marker, including launchers, receive the same treatment. Add
`unset HYPR_FULLSCREEN` to a per-game ScopeBuddy config to opt out.

## Punktfunk launches

SCB chooses the streaming path when a Punktfunk session is active and the focused
output is `PF-*`. Merely connecting the tablet does not redirect a local game.
Focus the intended screen before launching; this is a launch-time decision.
An unavailable Punktfunk status query retains the existing local-launch fallback.

- omit the local workspace-6 rule and LG HDR hooks for streamed launches
- size Gamescope and its frame cap to the actual stream dimensions and refresh
- retain native Wayland/HDR flags and existing per-game workarounds
- preserve valid HDR luminance metadata, even when its peak is below 1,000 nits
- use a 1,000-nit fallback only for an HDR output with absent peak metadata or a peak no higher than reference white
- abort launch on a metadata query failure rather than change an unknown output

`scb-output-luminance` extracts the output's color metadata from standard
`wayland-info` (wayland-utils 1.3+), which reads the same protocol used by Wine.
The fallback is compatibility metadata, not measured device brightness.
`SCB_PUNKTFUNK_HDR_MAX_LUMINANCE=0` disables it; a positive value up to 10,000
changes the fallback and must exceed reference white when applied. The correction
updates only `max_luminance` on Punktfunk's existing monitor rule. SDR streams
are unchanged. Stream exit leaves the virtual output's color mode to Punktfunk.

## Scale controls

`Super+/` increases scale and `Super+Alt+/` decreases it on the focused screen.

- physical outputs use stock `omarchy hyprland monitor scaling`
- `PF-*` outputs use `hypr-monitor-scale`, updating only the existing rule's scale at runtime; no color probe or config reload is needed
- round presets to clean fractional scales with sufficient precision; 2800×1752 steps from 1 to 4/3 rather than invalid 1.25
- keep virtual scale changes temporary; reconnecting or a config reload may restore Punktfunk's settings

For an explicit screen:

```sh
hypr-monitor-scale up --output PF-1
hypr-monitor-scale 1 --output PF-1
```

Physical-screen scaling uses Omarchy's normal persistence/reload path, so it can
also reset virtual runtime changes. Set the LG scale first when adjusting both.
The former hyprmoncfg TUI shortcut is removed.

## Local-only configuration

Punktfunk supplies its stock hooks during installation. Sunshine's app/server
configuration and service drop-in stay local; chezmoi does not manage them.

Retiring hyprmoncfg is a one-time local operation: disable its daemon and the old
display-session/waiter units, remove their custom files and generated monitor
include, then uninstall `hyprmoncfg-bin` and `hypr-sticky-hdr`. Reload user unit
definitions and Hyprland after replacing the monitor configuration. The repository
contains no retirement script or automatic file-removal manifest.
