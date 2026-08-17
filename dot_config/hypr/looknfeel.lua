-- Personal look'n'feel overrides; only what differs from Omarchy's defaults.

-- Niri-like side-scrolling layout (v4 stock: dwindle).
-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
hl.config({
  general = {
    layout = "scrolling",
  },
  scrolling = {
    column_width = 0.333,             -- default 0.5
    fullscreen_on_one_column = false, -- honor column_width for a lone column
  },
})

-- Workspace switching animation (v4 stock disables the workspaces leaf).
hl.curve("mybezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "mybezier", style = "slidevert" })

-- hyprfocus (hyprpm plugin) focus animation.
hl.curve("md3_accel", { type = "bezier", points = { { 0.03, 0 }, { 0.8, 0.15 } } })
hl.animation({ leaf = "hyprfocusIn", enabled = true, speed = 1.7, bezier = "md3_accel" })
hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "md3_accel" })

-- hyprpm plugin settings. `plugin` is missing from the lua-ls stubs, so the
-- warning is spurious; it works (verified with hyprctl getoption).
hl.config({
  plugin = {
    hyprfocus = { slide_height = 10 },                  -- default 20
    scrolloverview = { scale = 0.6, workspace_gap = 100 }, -- defaults 0.5, 0
  },
})
