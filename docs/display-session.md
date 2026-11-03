# Display control

- keep DP-1 in SDR for the desktop, with 10-bit color, fullscreen VRR, and SDR brightness 1.35
- use `scb -- %command%` for games; native launches enable LG HDR before Wine probes, Gamescope launches do so before the compositor starts
- restore LG SDR through ScopeBuddy's exit hook; preserve its current resolution, position, scale, and transform in both directions
- leave Punktfunk output creation, connection lifetime, placement, and negotiated SDR/HDR mode to Punktfunk
- retire hyprmoncfg, its profile wrapper, and automatic sticky-HDR detection

## ScopeBuddy configuration

- `scb.conf`: shared game settings, display values and startup calls
- `gamemode.conf`: ScopeBuddy's Gamescope entrypoint; symlinks to `scb.conf`
- `local.conf`: local workspace and FPS-margin preferences, without mode checks or exports
- `streaming.conf`: streaming workspace and FPS-margin preferences
- `common.sh`: game loading, mode selection, shared defaults, cached display getters and local HDR lifecycle
- `native.conf` and `gamescope.conf`: direct rendering or a new per-game compositor
- `session.conf`: reuse Steam's existing Gamescope, local or streamed
- `games/<game-name>.conf`: per-game overrides with a literal `APP_ID` declaration

Preferences and compositor ownership are independent:

| Launch | Preferences | Mode |
| --- | --- | --- |
| Local game on Hyprland | local | native |
| Local game wrapped in Gamescope | local | gamescope |
| Local Steam inside Gamescope | local | session |
| Native game on a Hyprland `PF-*` stream | streaming | native |
| Nested Gamescope on a Hyprland `PF-*` stream | streaming | gamescope |
| Punktfunk Steam inside Gamescope | streaming | session |

Native and nested streaming use Punktfunk's Hyprland compositor path. Session
streaming uses its Gamescope path. An existing Gamescope resolves per-game mode
preferences to session reuse. Session mode assumes an existing Gamescope compositor.
`gamemode.conf` is a relative symlink to `scb.conf`, sharing the same entrypoint.
`scb.conf` sets `mode=default`, calls `load_game_config` to source the matching
`APP_ID` file, then calls `apply_mode` once. The final step maps `default` to
`native`, or selects `session` inside existing Gamescope. Unknown IDs keep the
default. An explicit Gamescope selection never loads native defaults.

Existing Gamescope sessions keep their display environment, HDR, HUD settings,
resolution and frame pacing. SCB preserves caller-provided environment and hooks;
it neither queries nor changes Hyprland. Local HDR preparation for Steam inside
Gamescope belongs around the outer session, not each game. Shared performance
wrappers and per-game fixes still apply. ScopeBuddy itself disables the in-game
MangoHud layer in session mode; configure the outer session's HUD separately.
Preserve the outer session's `DXVK_HDR` and Vulkan layer environment: Punktfunk
sets `DXVK_HDR=1` for HDR sessions with a compatible Gamescope WSI layer. Session
mode does not force HDR for an SDR session.

Display values come from one launch-time snapshot:

- read the active LG `DP-1` mode for local desktop launches, or the focused active `PF-*` output for Hyprland streaming
- retain pixel dimensions regardless of desktop scale and preserve fractional refresh
- read the active `*` mode from `xrandr --current` on the inherited display inside Gamescope
- describe the game-facing display, not client encoding dimensions or measured frame throughput
- leave unavailable or ambiguous session metadata unknown; session reuse still works
- abort a desktop launch when its required display mode cannot be resolved

The getter interface is read-only after `display_init`:

| Function | Responsibility |
| --- | --- |
| `display_init` | resolve context and snapshot the active mode once in SCB's shell |
| `get_display_context` | return `local` or `streaming` |
| `get_display_width`, `get_display_height` | return cached pixel dimensions |
| `get_display_fps` | return cached advertised refresh, including fractions |
| `get_display_fps_cap margin` | round refresh and subtract the supplied margin, with a minimum of one |
| `scb_display_start` | prepare that target and wait for HDR readiness before launch |
| `scb_display_stop` | restore LG SDR only if this launch enabled HDR |

`scb.conf` reads the getters into `width`, `height`, `refresh`, and `fps_cap`.
The profiles contain only `workspace` and `fps_margin`: local uses workspace 6
and a margin of four; streaming preserves its workspace and uses no margin.
Geometry and caps therefore follow the active mode without resolution constants.
Gamescope's `-r` takes an integer, so its mode rounds the resolved refresh.

Punktfunk's API has stream dimensions but no verified association between its
session IDs and this game's compositor. The helper reads the compositor instead
of guessing the first stream. Existing sessions retain their own pacing and HDR;
the snapshot does not reconfigure them. A local outer Steam/Gamescope launcher
must own its geometry, placement and HDR lifecycle before any game starts.

ScopeBuddy skips its pre-command hook in native mode, so the native command uses
`pre_command && game`. Gamescope uses `scb_display_start || exit 1` in its
pre-hook because ScopeBuddy otherwise continues after a failure. Both modes use
the same exit hook. Source the helper in the runner's shell; separate executable
hooks would lose its in-memory cleanup state.

Native mode exports its Wayland/HDR defaults after loading game settings.
Explicit values, including zero, take precedence over those defaults. Native and nested Gamescope call `apply_desktop_defaults`
for shared desktop placement, HUD and cleanup. Session mode inherits the outer
compositor's environment. `gamescope.conf` enables adaptive-sync for local
launches only. SDR-to-HDR inverse tone mapping is off by default; a game config
can supply a complete `SCB_GAMESCOPE_ARGS` value including `--hdr-itm-enabled`
when needed. A nonempty value replaces the generated Gamescope arguments.

### Per-game overrides

ScopeBuddy supplies `SCB_APPID`, not a game-name variable. Declare the ID near the
top of each game file, using an unquoted literal assignment on its own line:

```bash
# games/control-resonant.conf
APP_ID=3669870
```

The loader reads declarations as text and sources only the first matching file.
Keep each ID in one file. Adding or renaming a game file needs no central map update.

`games/<game-name>.conf` loads once before mode configuration. Set `mode` and
other overrides as assignments; `command` still contains the unwrapped game:

```bash
mode=gamescope
fps_cap=60
export MANGOHUD=0
command="$command --game-option"
```

Omit `mode` to keep the default. Native and Gamescope preferences both resolve to
`session` inside an existing Gamescope compositor. The finalizer wraps the updated
command once, after all game settings and arguments have loaded.

`fps_margin` is profile policy: the cap is derived before game overrides load.
Changing `refresh` or `fps_margin` alone does not recalculate it; override `fps_cap`
explicitly. Unsetting a mode-owned flag now requests its default; use zero to
disable it. Explicit desktop HUD settings are retained, including inherited ones.

When installing this layout, move live-only game configs into `games/`, add their
`APP_ID` declarations, and archive old `AppID/*.conf` files outside `AppID/`. ScopeBuddy still loads matching
files there automatically; leaving them in place would run a second override.

```bash
export PROTON_ENABLE_WAYLAND=0  # opt out of Wine-Wayland in native mode
export DXVK_HDR=0              # opt out of native game HDR; LG still enters HDR
export HYPR_FULLSCREEN=0       # opt out of the Hyprland fullscreen rule
unset PROTON_DLSS_UPGRADE   # keep the shipped DLSS library
export MANGOHUD=0           # disable the native HUD
```

Gamescope's own fullscreen/HDR flags remain independent. Add arguments or replace
the raw `command` in the game file; the finalizer supplies performance wrappers
and hooks afterward. Avoid shell compounds in the Gamescope command: ScopeBuddy
embeds it inside Gamescope's argument list.

`game-performance` handles the idle/power hold; `gamemoderun` activates GameMode.
In Gamescope mode, mangoapp draws the HUD and the hidden in-game MangoHud layer
provides the exact FPS cap. Set `SCB_DEBUG=1` to log the expanded launch command.

Both desktop modes use `SCB_PRE_COMMAND` and `SCB_POST_COMMAND` from
`apply_desktop_defaults`. Native mode explicitly calls ScopeBuddy's internal
`pre_command` runner; nested mode runs it before starting Gamescope. Existing
session mode installs neither display hook.

Game configs can assign complete hook commands; an empty hook disables it.
The defaults are not available for appending while the game file loads.
The default pre-hook
uses `scb_display_start || exit 1`: ScopeBuddy only warns on ordinary failures.
Keep an explicit `exit` for fatal failures in custom hooks. Preparation runs after
ScopeBuddy installs its exit trap so cleanup retains the same shell's HDR state.

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
once when each window opens, then disables `sync_fullscreen` for that window so a
later client request cannot restore windowed geometry from another monitor.
Super+F still toggles compositor fullscreen; the game's display-mode label and
render resolution remain separate game settings.
Hidden anti-cheat windows retain their special-workspace exception. Other windows
inheriting the marker, including launchers, receive the same treatment. Add
`export HYPR_FULLSCREEN=0` to a per-game ScopeBuddy config to opt out.

## Punktfunk HDR capture

`hyprland.lua` allows 10-bit screencopy with `misc.screencopy_force_8b=false`.
Punktfunk owns virtual output creation and luminance metadata. Neither monitor
creation nor game launch supplies a peak-brightness override.

Native streamed games may not expose HDR when upstream metadata is invalid.
The existing Gamescope session path retains its compositor's HDR environment.

## Punktfunk launches

SCB identifies an existing Gamescope from the launch's `XDG_CURRENT_DESKTOP` or
`GAMESCOPE_WAYLAND_DISPLAY`, avoiding ScopeBuddy's global Steam-process heuristic.
Inside Gamescope, it selects streaming preferences only when `LIBEI_SOCKET`
matches a Punktfunk relay under `XDG_RUNTIME_DIR`: `punktfunk-gamescope-ei` or
`punktfunk-gamescope-*-ei`. Punktfunk writes this relay before starting Steam
([v0.46.0 source](https://git.unom.io/unom/punktfunk/src/tag/v0.46.0/crates/host/pf-vdisplay/src/vdisplay/linux/gamescope/spawn.rs)).
A missing runtime directory or unmatched relay uses local preferences but still
retains session mode, with no Hyprland hooks. This covers the normal user-session
launch; `/tmp` relay fallback and sandboxed clients need separate validation.

Outside Gamescope:

SCB chooses the streaming path when a Punktfunk session is active and the focused
output is `PF-*`. Merely connecting the tablet does not redirect a local game.
Focus the intended screen before launching; this is a launch-time decision.
An unavailable Punktfunk status query retains the existing local-launch fallback.

- omit the local workspace-6 rule and LG HDR hooks for streamed launches
- size Gamescope and its frame cap to the active virtual output's dimensions and refresh
- retain native Wayland/HDR flags and existing per-game workarounds
- leave all stream monitor rules and luminance metadata unchanged

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
