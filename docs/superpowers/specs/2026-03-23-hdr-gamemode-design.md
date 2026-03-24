# HDR Gamemode — Design Spec

## Problem

Hyprland's `cm_auto_hdr` works for initial fullscreen HDR passthrough, but breaks when alt-tabbing away and returning — most games don't reliably re-engage HDR. A "sticky" HDR mode that persists for the entire game session is more reliable.

Additionally, game windows launched via Steam should land on workspace 10.

## Solution

A single Bash daemon script (`hdr-gamemode`) that:
1. Listens to Hyprland IPC window events
2. Detects game windows (Steam-launched + configurable list)
3. Switches the monitor to full HDR config for the game's lifetime
4. Moves game windows to workspace 10
5. Switches back to SDR 5 seconds after the last game exits
6. Accepts manual `on/off/toggle/status` commands via UNIX socket

## Configuration (inline at top of script)

```bash
MONITOR_HDR="DP-3,5120x2160@165.06,auto,auto,bitdepth,10,cm,hdr,vrr,2,sdrbrightness,1.35,sdrsaturation,1.0"
MONITOR_SDR="DP-3,5120x2160@165.06,auto,auto,bitdepth,10,cm,auto,vrr,2,sdrbrightness,1.0,sdrsaturation,1.0"
STEAM_PATTERN="^steam_app_"
GAME_LIST=("cs2" "gamescope" "veloren")
COOLDOWN=5
GAME_WORKSPACE=10
CMD_FIFO="/tmp/hdr-gamemode-$UID.fifo"
REPLY_DIR="/tmp/hdr-gamemode-$UID-replies"
```

## Daemon Architecture

### Single main loop with merged inputs

All inputs (Hyprland events + user commands) are multiplexed through a single named pipe (FIFO). This keeps all state in one process.

**Event listener (background):** Connects to Hyprland's `.socket2.sock` via `socat`, prefixes each line with `EVT:`, and writes to the FIFO.

**Command input:** Client invocations (`hdr-gamemode on`) write `CMD:command:reply_id` to the FIFO. A per-request reply FIFO in `$REPLY_DIR` carries the response back.

**Main loop** reads from the FIFO and dispatches:
- `EVT:openwindow>>ADDR,WORKSPACE,CLASS,TITLE` — if class matches `STEAM_PATTERN` or `GAME_LIST`: track window, increment game counter, move to workspace 10, switch to HDR if first game
- `EVT:closewindow>>ADDR` — if tracked game window: decrement counter. If counter reaches 0: start 5s cooldown timer, then switch to SDR if still 0
- `CMD:on:reply_id` — force HDR (manual override)
- `CMD:off:reply_id` — clear override, switch to SDR immediately
- `CMD:toggle:reply_id` — toggle manual override
- `CMD:status:reply_id` — print mode, game count, override flag

### State

- Associative array: `GAME_WINDOWS[addr]=class` — tracked game windows
- Integer: `GAME_COUNT` — active game window count
- Boolean: `MANUAL_OVERRIDE` — manual HDR lock
- String: `CURRENT_MODE` — "hdr" or "sdr"

### CLI interface

The script is both daemon and client:
- `hdr-gamemode daemon` — start daemon (called from autostart.conf)
- `hdr-gamemode on|off|toggle|status` — send command to running daemon
- `hdr-gamemode` (no args) — print usage

### Monitor switching

```bash
hyprctl keyword monitor "$MONITOR_HDR"   # or $MONITOR_SDR
```

### Workspace assignment

```bash
hyprctl dispatch movetoworkspacesilent "10,address:0x$ADDR"
```

## Integration

- **Script path:** `~/.local/bin/hdr-gamemode` (chezmoi: `dot_local/bin/executable_hdr-gamemode`)
- **Autostart:** `exec-once = hdr-gamemode daemon` in `~/.config/hypr/autostart.conf`
- **Dependency:** `socat` added to `packages.yaml` (tags: [core])
- **DE gate:** Already handled — `dot_local/bin/` scripts with hyprland-specific behavior are fine; the autostart.conf line is in the hyprland-gated config
