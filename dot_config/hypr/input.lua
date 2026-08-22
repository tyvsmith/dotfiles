-- Personal input overrides; only what differs from Omarchy's defaults.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input

-- lan-mouse: Mac-friendly keyboard/mouse while the cursor is on the Mac client;
-- the mechanics are in hypr/lan_mouse.lua. The global is the hook target in
-- ~/.config/lan-mouse/config.toml:
--   enter_hook = "hyprctl eval 'lan_mouse.enter()'"
--   leave_hook = "hyprctl eval 'lan_mouse.leave()'"
lan_mouse = require("hypr.lan_mouse").setup({
  -- altwin:swap_alt_win: Alt/Super in the Mac's Option/Cmd positions.
  -- custom:printscreen_f13: PrtSc -> F13 (macOS has no PrtSc); defined in
  -- ~/.config/xkb/{rules/evdev,symbols/custom}.
  kb_options     = "altwin:swap_alt_win,custom:printscreen_f13",
  natural_scroll = true,
})

-- deskflow: forward modifiers to the input-capture client. With Hyprland's
-- default (false), pressing Super/Alt while driving a client recycles the libei
-- keyboard device in the same millisecond, the release is lost and the client
-- holds a stuck modifier (verified 2026-07-28, Hyprland 0.56.0 + deskflow
-- 1.26.0). Compositor behaviour, not a deskflow bug; retest after Hyprland
-- releases that touch input-capture. Off while lan-mouse is in use.
-- hl.config({ input_capture = { capture_modifiers = true } })
