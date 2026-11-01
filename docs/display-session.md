# Display control

- keep DP-1 in SDR for the desktop, with 10-bit color, fullscreen VRR, and SDR brightness 1.35
- use `scb -- %command%` for games; native launches enable LG HDR before Wine probes, Gamescope launches do so before the compositor starts
- restore LG SDR through ScopeBuddy's exit hook; preserve its current resolution, position, scale, and transform in both directions
- leave Punktfunk output creation, connection lifetime, placement, and negotiated SDR/HDR mode to Punktfunk
- retire hyprmoncfg, its profile wrapper, and automatic sticky-HDR detection

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

## Punktfunk launches

SCB chooses the streaming path when a Punktfunk session is active and the focused
output is `PF-*`. Merely connecting the tablet does not redirect a local game.
Focus the intended screen before launching; this is a launch-time decision.

- omit the local workspace-6 rule and LG HDR hooks for streamed launches
- size Gamescope and its frame cap to the actual stream dimensions and refresh
- retain native Wayland/HDR flags; keep per-game workarounds in local AppID files
- preserve valid HDR luminance metadata, even when its peak is below 1,000 nits
- use a 1,000-nit fallback only for an HDR output with absent peak metadata or a peak no higher than reference white
- abort launch on a metadata query failure rather than change an unknown output

`scb-output-luminance` reads the Wayland color-management event used by Wine.
The fallback is compatibility metadata, not measured device brightness.
`SCB_PUNKTFUNK_HDR_MAX_LUMINANCE=0` disables it; a positive value up to 10,000
changes the fallback and must exceed reference white when applied. SDR streams
are unchanged. Stream exit leaves the virtual output's color mode to Punktfunk.

## Scale controls

`Super+/` increases scale and `Super+Alt+/` decreases it on the focused screen.

- physical outputs use stock `omarchy hyprland monitor scaling`
- `PF-*` outputs use `hypr-monitor-scale`, applying only a runtime rule with the current mode, position and color settings
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
configuration and service drop-in, and Control's AppID overrides, stay local;
chezmoi does not manage them.

Retiring hyprmoncfg is a one-time local operation: disable its daemon and the old
display-session/waiter units, remove their custom files and generated monitor
include, then uninstall `hyprmoncfg-bin` and `hypr-sticky-hdr`. Reload user unit
definitions and Hyprland after replacing the monitor configuration. The repository
contains no retirement script or automatic file-removal manifest.
