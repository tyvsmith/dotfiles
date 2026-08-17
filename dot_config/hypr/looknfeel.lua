-- Personal look'n'feel overrides.
--
-- Only what differs from $OMARCHY_PATH/default/hypr/looknfeel.lua. Notably NOT
-- restated here: animations.enabled = true, which the 3.x looknfeel.conf set
-- explicitly but v4 now sets by default.

-- Niri-like side-scrolling layout. v4 stock is "dwindle".
hl.config({
  general = {
    layout = "scrolling",
  },

  -- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
  -- v4 stock sets only column_width = 0.49. Everything else in this table
  -- differs from Hyprland's compiled default; keys that merely restated the
  -- default (focus_fit_method, follow_focus, follow_min_visible, wrap_focus,
  -- wrap_swapcol, explicit_column_widths) were removed 2026-08-15.
  scrolling = {
    -- Default column width (0.1 - 1.0). Hyprland default 0.5.
    column_width = 0.333,
    -- Don't auto-maximize a lone column; honor column_width instead.
    -- Hyprland default true.
    fullscreen_on_one_column = false,
  },
})

-- Workspace switching animation. v4 stock ships
-- hl.animation({ leaf = "workspaces", enabled = false }), so this re-enables it.
-- hyprlang `bezier = name,x1,y1,x2,y2` becomes hl.curve(name, {points = ...}).
hl.curve("mybezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "mybezier", style = "slidevert" })

-- hyprfocus (hyprpm plugin) focus animation.
-- The 3.x config also defined an md3_decel curve that nothing referenced; it is
-- not carried over. Both leaves used md3_accel.
hl.curve("md3_accel", { type = "bezier", points = { { 0.03, 0 }, { 0.8, 0.15 } } })
hl.animation({ leaf = "hyprfocusIn", enabled = true, speed = 1.7, bezier = "md3_accel" })
hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "md3_accel" })

-- Compositor plugin settings (hyprpm, not the Quickshell `omarchy plugin` layer).
--
-- `plugin` is absent from HL.ConfigOpt in /usr/share/hypr/stubs/hl.meta.lua, so
-- lua-ls flags this block. It works -- verified 2026-08-14 by setting
-- scrolloverview.scale and reading it back with hyprctl getoption. Do not
-- "fix" the warning by deleting it.
hl.config({
  plugin = {
    -- hyprfocus defaults: slide_height = 20.
    hyprfocus = {
      slide_height = 10,
    },
    -- scrolloverview defaults: scale = 0.5, workspace_gap = 0.
    scrolloverview = {
      scale = 0.6,
      workspace_gap = 100,
    },
  },
})
