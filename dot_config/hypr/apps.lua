-- One ordered list of windowed apps. Data and lookup only: hypr/windows.lua
-- registers the rules, hypr/autostart.lua reads workspaces for boot launches.
--
-- ORDER IS PRECEDENCE. Hyprland keeps window rules in a plain vector and the
-- applicator walks it in registration order, so the LAST match wins. General
-- entries first, specific exceptions last.
--
-- Every app hypr/autostart.lua launches sets `silent`, so the STATIC rule alone
-- is enough to keep boot quiet. The exec rule autostart.lua attaches is a
-- belt-and-braces duplicate, not the mechanism: Hyprland only binds an exec rule
-- to a window whose own /proc/<pid>/environ still carries HL_EXEC_RULE_TOKEN, or
-- whose pid is the one Hyprland forked (WindowRule.cpp::matches, 0.56.2). A
-- launcher that forks instead of exec-ing breaks both -- Slack and
-- StreamController go bash-wrapper -> forked child inside the flatpak sandbox,
-- and the child has neither. Chromium also rewrites its own environ, which is
-- why vesktop keeps only the pid half. Exec rules additionally expire 60 s after
-- spawn, so a slow cold boot loses them even when the token survives.
--
-- Never set `name` on these rules. The wiki says named rules evaluate before
-- anonymous ones, which would break the ordering above; no such partition
-- exists in 0.56.2, but staying anonymous keeps it moot either way.
--
-- Fields:
--   id        required, unique. autostart.lua looks entries up by it.
--   match     required. Passed to o.window: a string is a class regex (RE2,
--             FULL match, backslashes doubled once for Lua and once for the
--             regex), a table matches any window property.
--   workspace optional. A number, or a selector such as "special:hidden".
--   silent    optional, default false. Adds " silent" to the STATIC rule so it
--             does not switch you to the workspace. Every app hypr/autostart.lua
--             launches sets it -- see the note above about exec rules.
--   rules     optional. Any other o.window effect, merged in verbatim.

local M = {}

M.list = {
  -- Workspace 4 -- messaging
  { id = "slack",   match = "com\\.slack\\.Slack", workspace = 4, silent = true },
  { id = "beeper",  match = "Beeper",              workspace = 4, silent = true },
  { id = "vesktop", match = "vesktop",             workspace = 4, silent = true },

  -- Workspace 5 -- Steam
  --
  -- Class-wide: everything Steam maps belongs on 5. Tiling is NOT class-wide --
  -- see steam_main below.
  { id = "steam",          match = "steam",          workspace = 5, silent = true },
  { id = "steamwebhelper", match = "steamwebhelper", workspace = 5, silent = true },
  { id = "protonplus",     match = "com\\.vysp3r\\.ProtonPlus", workspace = 5, silent = true },

  -- tile cancels the float in omarchy's default/hypr/apps/steam.lua. This list
  -- registers after the defaults, and the last matching rule wins. The center
  -- and 1100x700 size that came with that float are floating-only effects, so
  -- they go inert rather than needing an override of their own.
  --
  -- Steam maps its hover dropdowns as real top-level XWayland windows under the
  -- same class as its actual ones, so a class-wide tile drags a menu into the
  -- layout, where it claims a whole column and shoves real windows off the
  -- monitor. Enumerating titles does not scale either -- Settings, the browser,
  -- each chat, Game Servers, and every future panel would each need listing.
  --
  -- Discriminator, captured from a window.open log across a session where every
  -- kind was opened: a persistent window already carries its title when it maps,
  -- a transient popup maps untitled and never gets one. So "has any title at all"
  -- separates them exactly, with no list to maintain.
  --
  --   title=""             x many  -- dropdowns, hover panels
  --   title="Steam"                -- main window
  --   title="Friends List"         -- roster
  --   title="Steam Settings"       -- settings
  --   title="Steam - Browser"      -- in-client browser
  --   title="Game Servers"         -- servers dialog
  --   title="AltiniaHoldingsInc"   -- a chat window
  --
  -- `negative:` inverts an RE2 match, so this reads "class steam, title not
  -- empty". Failing closed is the safe direction here: anything that does map
  -- untitled keeps omarchy's float rather than being tiled by surprise.
  {
    id    = "steam_windows",
    match = { class = "^steam$", title = "negative:^$" },
    rules = { tile = true },
  },

  -- Notification toasts are titled, so steam_windows above tiles them and drops
  -- them into the scroll strip. They are transient overlays, not windows: float
  -- them back out and keep them from grabbing focus as they appear.
  --
  -- The title is Valve's, one counter per notification -- the same pattern the
  -- i3 and Niri configs match on. Anchored to digits so a real window that
  -- merely starts with the word cannot be swallowed by it.
  --
  -- MUST stay after steam_windows: both match, and the last one wins.
  {
    id    = "steam_toasts",
    match = { class = "^steam$", title = "^notificationtoasts_\\d+_desktop$" },
    rules = { float = true, no_initial_focus = true },
  },

  -- The two long-standing community rules for Steam's popups, which are the
  -- untitled windows identified above.
  --
  --   stay_focused  a popup that loses focus closes itself, and with
  --                 follow_mouse = 1 merely moving the pointer toward the menu
  --                 can do it. This is the standard fix for menus that vanish
  --                 the moment you reach for them.
  --   min_size 1x1  Hyprland otherwise imposes a floor on a floating window,
  --                 which stretches a small dropdown into something much larger
  --                 than the strip Steam drew.
  --
  -- Caveat kept deliberately: this exact pair froze Hyprland 0.35.0
  -- (hyprwm/Hyprland#4722). Long fixed by 0.56.2, but if the compositor ever
  -- locks up around a Steam menu, this is the first thing to pull.
  {
    id    = "steam_popups",
    match = { class = "^steam$", title = "^$" },
    rules = { stay_focused = true, min_size = { 1, 1 } },
  },

  -- Workspace 6 -- fullscreen/borderless games
  { id = "steam_games", match = "steam_app_.*", workspace = 6 },
  -- Only fires for a window already fullscreen when it maps: `workspace` is a
  -- static effect, so a window that goes fullscreen later never re-evaluates.
  -- Kept as-is pending a decision; it may be inert.
  { id = "fullscreen", match = { fullscreen = 1 }, workspace = 6 },

  -- Workspace 10 -- utilities
  { id = "streamcontroller", match = "com\\.core447\\.StreamController", workspace = 10, silent = true },
  { id = "lan_mouse",        match = "de\\.feschber\\.LanMouse",         workspace = 10, silent = true },

  -- Battle.net runs under Proton, so steam_games above already places it. This
  -- entry only cancels the float in omarchy's default/hypr/apps/battlenet.lua,
  -- matched exactly as omarchy matches it so the "Battle.net Setup" window and
  -- any other window sharing the class keep their own behaviour.
  --
  -- title is the initialTitle here: float and tile are static effects, so they
  -- are evaluated once at map time against the title the window opened with.
  {
    id    = "battlenet",
    match = { class = "^steam_app_battlenet$", title = "^Battle\\.net$" },
    rules = { tile = true },
  },

  -- MUST stay after steam_games: both match this window, and the last one wins.
  --
  -- HELLDIVERS 2 (appid 553850) maps an untitled nProtect GameGuard dialog as a
  -- native Wayland surface via winewayland.drv. It renders empty, never dismisses
  -- itself, takes focus, and as a floating window it is the sole reason the output
  -- reports solitaryBlockedBy = FLOAT while the game is fullscreen.
  --
  -- Discriminator verified against a live capture: the game's own window has
  -- initialTitle "HELLDIVERS™ 2", this one has "". Matching an empty initial_title
  -- therefore cannot catch the game itself.
  --
  -- Banished rather than closed, so GameGuard's process is left alone. Closing a
  -- specific window is not expressible here anyway: every hl.dsp.window.* call
  -- acts on the ACTIVE window, with no target argument.
  --
  -- Its own special workspace, not "scratchpad", so it never shows up when the
  -- real scratchpad is toggled (SUPER+SHIFT+S / SUPER+ALT+S). Nothing is bound to
  -- "hidden", which is the point -- it is reachable only on purpose:
  --   hyprctl dispatch 'hl.dsp.workspace.toggle_special("hidden")'
  --
  -- To generalise later, widen the class to "^steam_app_%d+$" -- but only after
  -- checking no other title maps a legitimately untitled window.
  {
    id        = "helldivers2_gameguard",
    match     = { class = "^steam_app_553850$", initial_title = "^$" },
    workspace = "special:hidden",
    silent    = true,
    rules     = { no_focus = true, no_initial_focus = true },
  },
}

M.by_id = {}
for i, app in ipairs(M.list) do
  assert(app.id, "hypr/apps.lua: entry #" .. i .. " has no id")
  assert(not M.by_id[app.id], "hypr/apps.lua: duplicate id " .. tostring(app.id))
  M.by_id[app.id] = app
end

function M.get(id)
  return assert(M.by_id[id], "hypr/apps.lua: no entry with id " .. tostring(id))
end

-- The single class an entry matches, for callers that need to compare a live
-- window's class by equality rather than re-running the regex. Only a literal
-- match converts: RE2 matches the class in FULL, so "com\\.slack\\.Slack" is
-- exactly the class com.slack.Slack, while "steam_app_.*" names a family and has
-- no single class. Escaped dots are the only metacharacter allowed through;
-- anything else is a programming error at this call site, not a silent miss.
function M.literal_class(app)
  assert(type(app.match) == "string",
    "hypr/apps.lua: " .. app.id .. " matches on window properties, not a class")

  local literal = app.match:gsub("\\%.", ".")
  assert(not app.match:gsub("\\%.", ""):find("[%.%^%$%*%+%?%(%)%[%]%{%}|\\]"),
    "hypr/apps.lua: " .. app.id .. " match is a pattern, not a literal class: " .. app.match)

  return literal
end

-- Hyprland's `workspace` effect is a string: a number or a selector such as
-- "special:hidden", optionally suffixed with " silent".
function M.workspace_arg(app, silent)
  assert(app.workspace, "hypr/apps.lua: " .. app.id .. " has no workspace")
  return tostring(app.workspace) .. (silent and " silent" or "")
end

return M
