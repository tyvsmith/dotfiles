-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Personal overrides. Bindings stack rather than replace, so an occupied key
-- needs hl.unbind() first (see: omarchy menu keybindings --print). Commented
-- bindings are the 3.x set, ported and left inert to adopt one at a time.

-- Applications (keys taken by Omarchy 4)
-- hl.unbind("SUPER + ALT + RETURN") -- v4: tmux attach || tmux new -s Work
-- o.bind("SUPER + ALT + RETURN", "Tmux", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new')
-- hl.unbind("SUPER + SHIFT + E") -- v4: Email (Hey); editor moved to SUPER + SHIFT + N
-- o.bind("SUPER + SHIFT + E", "Editor", "omarchy-launch-editor")
-- hl.unbind("SUPER + SHIFT + C") -- v4: Calendar (Hey)
-- o.bind("SUPER + SHIFT + C", "Chat (Beeper)", { launch = "beeper", focus = "^beeper$" })
-- hl.unbind("SUPER + SHIFT + G") -- v4: Signal
-- o.bind("SUPER + SHIFT + G", "Steam", { launch = "steam", focus = "^steam$" })

-- Web apps
-- hl.unbind("SUPER + SHIFT + ALT + A") -- v4: Grok (ChatGPT is already SUPER + SHIFT + A)
-- o.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https://chatgpt.com", focus = true })
-- o.bind("SUPER + SHIFT + CTRL + A", "Claude", { webapp = "https://claude.ai", focus = true })
-- o.bind("SUPER + SHIFT + ALT + C", "Google Calendar", { webapp = "https://calendar.google.com", focus = true })
-- hl.unbind("SUPER + SHIFT + ALT + E") -- v4: New email (Hey)
-- o.bind("SUPER + SHIFT + ALT + E", "Gmail", { webapp = "https://gmail.com", focus = true })
-- hl.unbind("SUPER + SHIFT + ALT + G") -- v4: WhatsApp
-- o.bind("SUPER + SHIFT + ALT + G", "Github", { webapp = "https://github.com/" })

-- Omarchy web apps not wanted
hl.unbind("SUPER + SHIFT + C")         -- Calendar (Hey)
hl.unbind("SUPER + SHIFT + E")         -- Email (Hey)
hl.unbind("SUPER + SHIFT + ALT + E")   -- New email (Hey)
hl.unbind("SUPER + SHIFT + ALT + G")   -- WhatsApp
hl.unbind("SUPER + SHIFT + CTRL + G")  -- Google Messages
hl.unbind("SUPER + SHIFT + ALT + X")   -- X Post
hl.unbind("SUPER + SHIFT + G")         -- Signal
-- hl.unbind("SUPER + SHIFT + ALT + A")   -- Grok
-- hl.unbind("SUPER + SHIFT + Y")         -- YouTube
-- hl.unbind("SUPER + SHIFT + P")         -- Google Photos
-- hl.unbind("SUPER + SHIFT + S")         -- Google Maps
-- hl.unbind("SUPER + SHIFT + X")         -- X
-- hl.unbind("SUPER + SHIFT + W")         -- Omawrite

-- Dictation toggle (F16 = evdev keycode 186 -> xkb keycode 194)
o.bind("code:194", "Toggle dictation", "voxtype-smart-toggle")
-- Free F9 for app shortcuts (v4 binds it for push-to-talk, press and release)
-- hl.unbind("F9")

-- Workspace navigation
o.bind("SUPER + page_down", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + page_up", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + SHIFT + page_down", "Move to next workspace", hl.dsp.window.move({ workspace = "e+1" }))
o.bind("SUPER + SHIFT + page_up", "Move to previous workspace", hl.dsp.window.move({ workspace = "e-1" }))

-- Invert SUPER+scroll to match natural-scroll direction (v4 binds it the other way)
o.bind("SUPER + SHIFT + mouse_down", "Move to previous workspace", hl.dsp.window.move({ workspace = "e-1" }))
o.bind("SUPER + SHIFT + mouse_up", "Move to next workspace", hl.dsp.window.move({ workspace = "e+1" }))

-- Dock and overview
-- o.bind("SUPER + D", "Toggle Dock", "hypr-dock")
o.bind("SUPER + E", "Overview", hl.plugin.scrolloverview.overview("toggle"))

-- Scrolling layout (Hyprland 0.55+ first-class bindings)

-- Column composition (Niri-style; the COMMA family is owned by notifications)
o.bind("SUPER + bracketleft", "Consume or expel toward prev", hl.dsp.layout("consume_or_expel prev"))
o.bind("SUPER + bracketright", "Consume or expel toward next", hl.dsp.layout("consume_or_expel next"))
o.bind("SUPER + period", "Expel window into its own column", hl.dsp.layout("expel"))
o.bind("SUPER + SHIFT + period", "Consume window into previous column", hl.dsp.layout("consume"))
o.bind("SUPER + ALT + period", "Promote window out of stack", hl.dsp.layout("promote"))

-- Column reordering (leaves SUPER+ALT+arrows for groups)
o.bind("SUPER + SHIFT + bracketleft", "Move column left", hl.dsp.layout("swapcol l"))
o.bind("SUPER + SHIFT + bracketright", "Move column right", hl.dsp.layout("swapcol r"))

-- Fit / zoom (SUPER+CTRL+I is Omarchy's idle-lock toggle)
o.bind("SUPER + I", "Fit active column", hl.dsp.layout("fit active"))
o.bind("SUPER + ALT + I", "Fit visible columns", hl.dsp.layout("fit visible"))
o.bind("SUPER + SHIFT + I", "Fit entire tape", hl.dsp.layout("fit all"))

-- Center the active column (Niri's Mod+C)
o.bind("SUPER + ALT + C", "Center active column", hl.dsp.layout("center"))

-- Tape-end peek; v4 binds SUPER + Home to "Restore window width" (note the case)
-- hl.unbind("SUPER + Home")
-- o.bind("SUPER + Home", "Slide view to first column", hl.dsp.layout("fit tobeg"))
-- o.bind("SUPER + End", "Slide view to last column", hl.dsp.layout("fit toend"))

-- Column width cycling (presets in scrolling.explicit_column_widths)
o.bind("SUPER + R", "Cycle column width forward", hl.dsp.layout("colresize +conf"))
o.bind("SUPER + SHIFT + R", "Cycle column width backward", hl.dsp.layout("colresize -conf"))

-- View pinning (stop auto-scrolling on focus changes)
-- o.bind("SUPER + backslash", "Toggle scroll inhibit (pin view)", hl.dsp.layout("inhibit_scroll"))

-- View-only mouse scroll (SUPER+mouse = workspace nav; SUPER+ALT+mouse = group nav)
-- o.bind("SUPER + mouse_left", "Scroll view one column backward", hl.dsp.layout("move -col"))
-- o.bind("SUPER + mouse_right", "Scroll view one column forward", hl.dsp.layout("move +col"))
-- o.bind("SUPER + SHIFT + mouse_left", "Move column left", hl.dsp.layout("swapcol l"))
-- o.bind("SUPER + SHIFT + mouse_right", "Move column right", hl.dsp.layout("swapcol r"))

-- Incremental scroll (repeat while held)
o.bind("SUPER + CTRL + bracketleft", "Slow-scroll view left", hl.dsp.layout("move +120"), { repeating = true })
o.bind("SUPER + CTRL + bracketright", "Slow-scroll view right", hl.dsp.layout("move -120"), { repeating = true })

-- Freeze/unfreeze the active process
o.bind("SUPER + XF86AudioPlay", nil, "wl-freeze -a")
