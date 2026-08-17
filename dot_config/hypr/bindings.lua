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




-- Personal keybinding overrides.
--
-- ============================================================================
-- EVERYTHING BELOW IS COMMENTED OUT ON PURPOSE.
--
-- These are the bindings from the 3.x bindings.conf, translated to v4 Lua and
-- left inert so they can be adopted one at a time. Uncomment a block, save
-- (Hyprland auto-reloads), try it, keep or delete.
--
-- Omarchy's preinstalled app/webapp bindings are LEFT ENABLED -- neither
-- omarchy_default_bindings nor omarchy_preinstalled_bindings is set in
-- hyprland.lua. That means v4 currently owns some of these keys, so several
-- blocks below need their hl.unbind() line uncommented too. Each says so.
--
-- See what is bound right now:  omarchy menu keybindings --print
-- ============================================================================
--
-- Translation reference, for anything else ported later:
--   bindd  = MOD, KEY, Desc, exec, cmd  ->  o.bind("MOD + KEY", "Desc", "cmd")
--   bindde = ... (repeats)              ->  o.bind(..., { repeating = true })
--   bind   = ... (no description)       ->  o.bind("MOD + KEY", nil, "cmd")
--   unbind = MOD, KEY                   ->  hl.unbind("MOD + KEY")
--   layoutmsg, <msg>                    ->  hl.dsp.layout("<msg>")
--   workspace, e+1                      ->  hl.dsp.focus({ workspace = "e+1" })
--   movetoworkspace, e+1                ->  hl.dsp.window.move({ workspace = "e+1" })
--   scrolloverview:overview, toggle     ->  hl.plugin.scrolloverview.overview("toggle")
--
-- Bindings stack rather than replace -- v4 deliberately binds ALT+TAB twice --
-- so re-binding an occupied key without hl.unbind() leaves BOTH active.


-- ============================================================================
-- ALREADY PROVIDED BY OMARCHY 4 -- nothing to do
-- ============================================================================
-- These were in the 3.x file but were byte-identical to Omarchy's own 3.8.5
-- template, and v4 still ships each one. They are listed only so it is clear
-- they were considered and are not missing:
--
--   SUPER + RETURN              Terminal
--   SUPER + SHIFT + RETURN      Browser
--   SUPER + SHIFT + B           Browser
--   SUPER + SHIFT + ALT + B     Browser (private)
--   SUPER + SHIFT + F           File manager
--   SUPER + ALT + SHIFT + F     File manager (cwd)
--   SUPER + SHIFT + M           Music (spotify)
--   SUPER + SHIFT + ALT + M     Music TUI (cliamp)
--   SUPER + SHIFT + D           Docker (lazydocker)
--   SUPER + SHIFT + O           Obsidian
--   SUPER + SHIFT + SLASH       Passwords (1password)
--
-- Also note v4 moved two things: the Editor is now SUPER + SHIFT + N, and
-- ChatGPT is now SUPER + SHIFT + A. If those keys suit you, the corresponding
-- blocks below can simply be deleted rather than uncommented.


-- ============================================================================
-- APPLICATIONS -- these keys are TAKEN by Omarchy 4
-- ============================================================================

-- Tmux. Only the command differs: v4 runs `tmux attach || tmux new -s Work`,
-- this runs a plain `tmux new`.
-- hl.unbind("SUPER + ALT + RETURN")
-- o.bind("SUPER + ALT + RETURN", "Tmux",
--   'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new')

-- Editor on SHIFT+E. v4 uses this key for Email (Hey) and puts the editor on
-- SUPER + SHIFT + N.
-- hl.unbind("SUPER + SHIFT + E")
-- o.bind("SUPER + SHIFT + E", "Editor", "omarchy-launch-editor")

-- Beeper on SHIFT+C. v4 uses this key for the Hey calendar webapp.
-- hl.unbind("SUPER + SHIFT + C")
-- o.bind("SUPER + SHIFT + C", "Chat (Beeper)", { launch = "beeper", focus = "^beeper$" })

-- Steam on SHIFT+G. v4 uses this key for Signal.
-- hl.unbind("SUPER + SHIFT + G")
-- o.bind("SUPER + SHIFT + G", "Steam", { launch = "steam", focus = "^steam$" })


-- ============================================================================
-- WEB APPS
-- ============================================================================
-- In 3.x these replaced Omarchy's webapp set by deleting its lines. That no
-- longer works: the user file starts empty and Omarchy's live in
-- default/hypr/bindings/applications.lua, so its webapps are all active again.
-- Uncommenting an unbind below removes one of them.

-- ChatGPT. v4 uses SHIFT+ALT+A for Grok -- and already gives you ChatGPT on
-- SUPER + SHIFT + A, so consider just using that instead of this block.
-- hl.unbind("SUPER + SHIFT + ALT + A")
-- o.bind("SUPER + SHIFT + ALT + A", "ChatGPT", { webapp = "https://chatgpt.com", focus = true })

-- Claude. Key is free in v4.
-- o.bind("SUPER + SHIFT + CTRL + A", "Claude", { webapp = "https://claude.ai", focus = true })

-- Google Calendar. Key is free in v4 (its calendar is on SHIFT+C).
-- o.bind("SUPER + SHIFT + ALT + C", "Google Calendar", { webapp = "https://calendar.google.com", focus = true })

-- Gmail. v4 uses SHIFT+ALT+E for "New email" (Hey).
-- hl.unbind("SUPER + SHIFT + ALT + E")
-- o.bind("SUPER + SHIFT + ALT + E", "Gmail", { webapp = "https://gmail.com", focus = true })

-- Github. v4 uses SHIFT+ALT+G for WhatsApp.
-- hl.unbind("SUPER + SHIFT + ALT + G")
-- o.bind("SUPER + SHIFT + ALT + G", "Github", { webapp = "https://github.com/" })

-- Omarchy 4 webapps you deleted in 3.x and which are therefore BACK. Uncomment
-- any you still don't want:
-- hl.unbind("SUPER + SHIFT + ALT + A")   -- Grok
hl.unbind("SUPER + SHIFT + C")         -- Calendar (Hey)
hl.unbind("SUPER + SHIFT + E")         -- Email (Hey)
hl.unbind("SUPER + SHIFT + ALT + E")   -- New email (Hey)
-- hl.unbind("SUPER + SHIFT + Y")         -- YouTube
hl.unbind("SUPER + SHIFT + ALT + G")   -- WhatsApp
hl.unbind("SUPER + SHIFT + CTRL + G")  -- Google Messages
-- hl.unbind("SUPER + SHIFT + P")         -- Google Photos
-- hl.unbind("SUPER + SHIFT + S")         -- Google Maps
-- hl.unbind("SUPER + SHIFT + X")         -- X
hl.unbind("SUPER + SHIFT + ALT + X")   -- X Post
hl.unbind("SUPER + SHIFT + G")         -- Signal
-- hl.unbind("SUPER + SHIFT + W")         -- Omawrite


-- ============================================================================
-- DICTATION
-- ============================================================================
-- F16 -> evdev keycode 186 -> xkb keycode 194. Key is free in v4.
o.bind("code:194", "Toggle dictation", "voxtype-smart-toggle")

-- Free F9 for app shortcuts. v4's bindings/voxtype.lua binds F9 TWICE, press
-- and release, for push-to-talk -- confirm one unbind clears both.
-- It also adds SUPER + CTRL + X as a dictation toggle, which is new in v4.
-- hl.unbind("F9")


-- ============================================================================
-- WORKSPACE NAVIGATION
-- ============================================================================
-- Page keys. Free in v4.
o.bind("SUPER + page_down", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + page_up", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + SHIFT + page_down", "Move to next workspace", hl.dsp.window.move({ workspace = "e+1" }))
o.bind("SUPER + SHIFT + page_up", "Move to previous workspace", hl.dsp.window.move({ workspace = "e-1" }))

-- Invert SUPER+scroll to match natural-scroll direction. v4 binds both of these
-- the other way round, so the unbinds are required.
o.bind("SUPER + SHIFT + mouse_down", "Move to previous workspace", hl.dsp.window.move({ workspace = "e-1" }))
o.bind("SUPER + SHIFT + mouse_up", "Move to next workspace", hl.dsp.window.move({ workspace = "e+1" }))


-- ============================================================================
-- DOCK AND OVERVIEW
-- ============================================================================
-- Both keys are free in v4.
-- o.bind("SUPER + D", "Toggle Dock", "hypr-dock")

-- scrolloverview registers its own Lua namespace, so no hyprctl shell-out.
-- hl.plugin.scrolloverview also exposes navigate, gesture, window, configure.
o.bind("SUPER + E", "Overview", hl.plugin.scrolloverview.overview("toggle"))


-- ============================================================================
-- SCROLLING LAYOUT (Hyprland 0.55+ first-class bindings)
-- ============================================================================
-- Every key in this section is free in v4 EXCEPT SUPER + Home, noted below.

-- Column composition (Niri-style; the COMMA family is owned by notifications).
o.bind("SUPER + bracketleft", "Consume or expel toward prev", hl.dsp.layout("consume_or_expel prev"))
o.bind("SUPER + bracketright", "Consume or expel toward next", hl.dsp.layout("consume_or_expel next"))
o.bind("SUPER + period", "Expel window into its own column", hl.dsp.layout("expel"))
o.bind("SUPER + SHIFT + period", "Consume window into previous column", hl.dsp.layout("consume"))
o.bind("SUPER + ALT + period", "Promote window out of stack", hl.dsp.layout("promote"))

-- Column reordering on the tape (leaves SUPER+ALT+arrows for groups).
o.bind("SUPER + SHIFT + bracketleft", "Move column left", hl.dsp.layout("swapcol l"))
o.bind("SUPER + SHIFT + bracketright", "Move column right", hl.dsp.layout("swapcol r"))

-- Fit / zoom -- I family (Inspect). SUPER+CTRL+I is Omarchy's idle-lock toggle.
o.bind("SUPER + I", "Fit active column", hl.dsp.layout("fit active"))
o.bind("SUPER + ALT + I", "Fit visible columns", hl.dsp.layout("fit visible"))
o.bind("SUPER + SHIFT + I", "Fit entire tape", hl.dsp.layout("fit all"))

-- Center the active column (Niri's Mod+C analog).
o.bind("SUPER + ALT + C", "Center active column", hl.dsp.layout("center"))

-- Tape-end peek (slides the view; does not change focus).
-- NOTE: v4 binds SUPER + Home to "Restore window width", so that unbind is
-- required. Mind the capitalisation -- v4 writes "Home", not "HOME".
-- hl.unbind("SUPER + Home")
-- o.bind("SUPER + Home", "Slide view to first column", hl.dsp.layout("fit tobeg"))
-- o.bind("SUPER + End", "Slide view to last column", hl.dsp.layout("fit toend"))

-- Column width cycling (presets in scrolling.explicit_column_widths).
o.bind("SUPER + R", "Cycle column width forward", hl.dsp.layout("colresize +conf"))
o.bind("SUPER + SHIFT + R", "Cycle column width backward", hl.dsp.layout("colresize -conf"))

-- View pinning (stop auto-scrolling on focus changes).
-- o.bind("SUPER + backslash", "Toggle scroll inhibit (pin view)", hl.dsp.layout("inhibit_scroll"))

-- View-only mouse scroll -- focus stays, the camera slides over the tape.
-- SUPER+mouse = workspace nav; SUPER+ALT+mouse = group nav.
-- o.bind("SUPER + mouse_left", "Scroll view one column backward", hl.dsp.layout("move -col"))
-- o.bind("SUPER + mouse_right", "Scroll view one column forward", hl.dsp.layout("move +col"))
-- o.bind("SUPER + SHIFT + mouse_left", "Move column left", hl.dsp.layout("swapcol l"))
-- o.bind("SUPER + SHIFT + mouse_right", "Move column right", hl.dsp.layout("swapcol r"))

-- Incremental scroll. `bindde` (repeat-while-held) becomes repeating = true.
o.bind("SUPER + CTRL + bracketleft", "Slow-scroll view left", hl.dsp.layout("move +120"), { repeating = true })
o.bind("SUPER + CTRL + bracketright", "Slow-scroll view right", hl.dsp.layout("move -120"), { repeating = true })


-- ============================================================================
-- MISC
-- ============================================================================
-- Freeze/unfreeze the active process. Key is free in v4.
o.bind("SUPER + XF86AudioPlay", nil, "wl-freeze -a")
