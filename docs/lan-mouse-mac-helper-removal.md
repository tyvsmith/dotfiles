# lan-mouse-extended: Future Removal

Tracking upstream lan-mouse features that would make `~/.local/bin/lan-mouse-extended` unnecessary.

The helper is a workaround that monitors cursor position to toggle Hyprland input settings (natural scroll, alt/win swap) when the cursor moves to a Mac client. It also syncs StreamController button state with lan-mouse connection status. It runs as a persistent background service via `~/.config/hypr/autostart.conf`.

## Features (all opt-in via flags)

| Flag | Description |
|---|---|
| `--natural-scroll` | Toggle natural scrolling on Razer mouse dock when cursor moves to Mac client |
| `--swap-keys` | Swap alt/win on Keychron keyboard when cursor moves to Mac client |
| `--remap-printscreen` | Remap PrtScr to F13 on Keychron keyboard when cursor moves to Mac client (macOS has no PrtScr key) |
| `--sync-streamdeck` | Auto-detect lan-mouse button in StreamController and sync state (green=idle, red=active) |
| `-q` / `--quiet` | Suppress log output |

## What needs to happen upstream

### Swap alt/meta per client

lan-mouse needs per-client modifier key remapping so alt and super can be swapped when sending input to a macOS client, eliminating the `hyprctl keyword ... kb_options "altwin:swap_alt_win"` workaround.

**Tracking:** [feschber/lan-mouse#361 — [Feature Request] Swap alt/meta](https://github.com/feschber/lan-mouse/issues/361)

### Natural scrolling per client

lan-mouse needs per-client scroll direction configuration so natural scrolling can be enabled for macOS clients without toggling the Hyprland device setting.

**Tracking:** No dedicated issue. Related scroll issues:
- [feschber/lan-mouse#133 — Mouse wheel distance/speed](https://github.com/feschber/lan-mouse/issues/133)
- [feschber/lan-mouse#331 — Jumping Mousewheel and no Double Click MacOS Client](https://github.com/feschber/lan-mouse/issues/331)

General macOS support tracker: [feschber/lan-mouse#36 — Tracking issue for MacOS support](https://github.com/feschber/lan-mouse/issues/36)

### Remap PrtScr to F13 per client

lan-mouse needs per-client key remapping so Print Screen can be sent as F13 to a macOS client (macOS has no Print Screen key), eliminating the custom XKB `kb_options` workaround. The remap is implemented as a `custom:printscreen_f13` XKB option defined in `~/.config/xkb/rules/evdev` and `~/.config/xkb/symbols/custom`, toggled on the Keychron via `hyprctl keyword ... kb_options`.

**Tracking:** No dedicated issue; covered by the general per-client remapping need. Related: [feschber/lan-mouse#361 — [Feature Request] Swap alt/meta](https://github.com/feschber/lan-mouse/issues/361)

## What to remove when ready

1. Delete `~/.local/bin/lan-mouse-extended`
2. Remove `exec-once = ~/.local/bin/lan-mouse-extended ...` from `~/.config/hypr/autostart.conf`
3. Delete `~/.config/xkb/rules/evdev` and `~/.config/xkb/symbols/custom` (the `custom:printscreen_f13` option)
4. Delete this file
