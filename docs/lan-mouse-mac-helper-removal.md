# lan-mouse Mac input helper: future removal

Tracks the upstream lan-mouse features that would make `~/.config/hypr/lan_mouse.lua` unnecessary.

The helper is a workaround: while the cursor is on the Mac client it swaps Alt/Super, remaps Print Screen to F13, and turns on natural scrolling, all via Hyprland's `input` options. lan-mouse's per-client `enter_hook`/`leave_hook` call into it with `hyprctl eval 'lan_mouse.enter()'` / `'lan_mouse.leave()'`; a `layer.closed` guard on lan-mouse's barrier layer restores defaults if lan-mouse deactivates, quits, or crashes without firing `leave_hook`.

## What needs to happen upstream

### Swap alt/meta per client

lan-mouse needs per-client modifier key remapping so alt and super can be swapped when sending input to a macOS client, eliminating the `altwin:swap_alt_win` `kb_options` workaround.

**Tracking:** [feschber/lan-mouse#361 — [Feature Request] Swap alt/meta](https://github.com/feschber/lan-mouse/issues/361)

### Natural scrolling per client

lan-mouse needs per-client scroll direction configuration so natural scrolling can be enabled for macOS clients without toggling the Hyprland setting.

**Tracking:** No dedicated issue. Related scroll issues:
- [feschber/lan-mouse#133 — Mouse wheel distance/speed](https://github.com/feschber/lan-mouse/issues/133)
- [feschber/lan-mouse#331 — Jumping Mousewheel and no Double Click MacOS Client](https://github.com/feschber/lan-mouse/issues/331)

General macOS support tracker: [feschber/lan-mouse#36 — Tracking issue for MacOS support](https://github.com/feschber/lan-mouse/issues/36)

### Remap PrtScr to F13 per client

lan-mouse needs per-client key remapping so Print Screen can be sent as F13 to a macOS client (macOS has no Print Screen key), eliminating the custom XKB `kb_options` workaround. The remap is the `custom:printscreen_f13` XKB option defined in `~/.config/xkb/rules/evdev` and `~/.config/xkb/symbols/custom`.

**Tracking:** No dedicated issue; covered by the general per-client remapping need. Related: [feschber/lan-mouse#361 — [Feature Request] Swap alt/meta](https://github.com/feschber/lan-mouse/issues/361)

## What to remove when ready

1. Delete `~/.config/hypr/lan_mouse.lua` and its `require("hypr.lan_mouse")` in `~/.config/hypr/hyprland.lua`
2. Drop `enter_hook`/`leave_hook` from the client in `~/.config/lan-mouse/config.toml`
3. Delete `~/.config/xkb/rules/evdev` and `~/.config/xkb/symbols/custom` (the `custom:printscreen_f13` option)
4. Delete this file
