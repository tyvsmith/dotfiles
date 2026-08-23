-- One ordered list of windowed apps. Data and lookup only: hypr/windows.lua
-- registers the rules, hypr/autostart.lua reads workspaces for boot launches.
--
-- ORDER IS PRECEDENCE. Hyprland keeps window rules in a plain vector and the
-- applicator walks it in registration order, so the LAST match wins. General
-- entries first, specific exceptions last.
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
--             does not switch you to the workspace.
--   rules     optional. Any other o.window effect, merged in verbatim.

local M = {}

M.list = {
  -- Workspace 4 -- messaging
  { id = "slack",   match = "com\\.slack\\.Slack", workspace = 4 },
  { id = "beeper",  match = "Beeper",              workspace = 4 },
  { id = "vesktop", match = "vesktop",             workspace = 4 },

  -- Workspace 5 -- Steam
  { id = "steam",          match = "steam",          workspace = 5 },
  { id = "steamwebhelper", match = "steamwebhelper", workspace = 5 },
  { id = "protonplus",     match = "protonplus",     workspace = 5 },

  -- Workspace 6 -- fullscreen/borderless games
  { id = "steam_games", match = "steam_app_.*", workspace = 6 },
  -- Only fires for a window already fullscreen when it maps: `workspace` is a
  -- static effect, so a window that goes fullscreen later never re-evaluates.
  -- Kept as-is pending a decision; it may be inert.
  { id = "fullscreen", match = { fullscreen = 1 }, workspace = 6 },

  -- Workspace 10 -- utilities
  { id = "streamcontroller", match = "com\\.core447\\.StreamController", workspace = 10 },
  { id = "lan_mouse",        match = "de\\.feschber\\.LanMouse",         workspace = 10 },

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

-- Hyprland's `workspace` effect is a string: a number or a selector such as
-- "special:hidden", optionally suffixed with " silent".
function M.workspace_arg(app, silent)
  assert(app.workspace, "hypr/apps.lua: " .. app.id .. " has no workspace")
  return tostring(app.workspace) .. (silent and " silent" or "")
end

return M
