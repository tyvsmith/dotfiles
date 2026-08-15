-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.envs")
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("hypr.windows")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.

-- deskflow: forward modifiers to the input-capture client instead of letting
-- Hyprland handle them locally. With Hyprland's default (false), pressing
-- Super/Alt while driving a deskflow client recycles the libei "captured
-- keyboard" device (EI_EVENT_DEVICE_REMOVED) in the same millisecond as the
-- keypress: the release is never delivered, the client is left holding a stuck
-- modifier, and every further key is dropped until you cross screens.
-- Verified 2026-07-28 on Hyprland 0.56.0 + deskflow 1.26.0 -- 8/8 modifier
-- presses lost their release with this off, 8/8 delivered it with this on.
--
-- Side effect: while a client is capturing, Hyprland also skips its LED sync,
-- so CapsLock/NumLock indicators lag until you switch back. Self-correcting.
-- Dormant whenever nothing holds an InputCapture portal session.
--
-- Note the Lua key is input_capture (underscore), not the hyprlang
-- input-capture (hyphen) this was ported from.
--
-- Removal test -- this works around compositor behaviour, not a deskflow bug, so
-- retest after any Hyprland release that touches input-capture. (v0.56.1's
-- input-capture commits #15477/#15520 do NOT address this; as of 2026-07-28
-- nothing is filed upstream for the device-recycle itself.)
--   hyprctl keyword input_capture:capture_modifiers false
--   -- drive the client, press Super, keep typing -- still typing = fixed upstream
--   hyprctl keyword input_capture:capture_modifiers true   -- instant revert
hl.config({ input_capture = { capture_modifiers = true } })
