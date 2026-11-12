-- hlsovpp: ScrollOverview with per-window motion (jgarza.hlsovpp).
-- Fork of https://github.com/yayuuu/hyprland-scroll-overview
-- Written by the panel: omarchy-shell shell toggle jgarza.hlsovpp
-- Hand edits are fine - the panel reads this file back. Keep one key per line.

if hl.plugin.scrolloverview then
  hl.config({ plugin = { scrolloverview = {
    scale = 0.5,
    workspace_gap = 0,
    layout = "vertical",
    gesture_distance = 200,
    cross_monitor_drag = true,
    wallpaper = 0,
    blur = false,
    shadow = {
      enabled = false,
      range = 50,
    },
    labels = {
      enabled = true,
      font_size = 18,
      position = "center",
      icon = true,
      clean_title = true,
      title_format = "$title",
      radius = 1,
      background_color = "#0d0d12",
      background_opacity = 0.72,
      text_color = "#ffffff",
      border_color = "accent",
      border = true,
      border_width = 0,
    },
    motion = {
      style = "ripple",
      spread = 0.35,
      origin = "focus",
      direction = "forward",
      easing = "follow",
      speed = 0,
      tilt = 0,
      rewind_on_close = true,
      on_gesture = false,
    },
    input = {
      scrolling_mode = 0,
      drag_mode = 0,
      drag_threshold = 10,
      touchpad_scroll_factor = 1,
      scroll_event_delay = 200,
    },
  } } })
end
