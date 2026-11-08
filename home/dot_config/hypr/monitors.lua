-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all
--
-- Kept on their own lines: `omarchy hyprland monitor scaling` rewrites these two
-- by regex. GDK_SCALE must stay 1 on this scale-1 5120x2160 panel; stock's 2
-- doubles every XWayland/CEF app (Spotify).
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Only registered outputs participate in local HDR; Punktfunk owns its outputs.
launch_hdr = require("hypr.hdr").setup({
  {
    output = "DP-1", mode = "preferred", position = "0x0",
    scale = omarchy_monitor_scale, bitdepth = 10, vrr = 2,
    cm = "srgb", sdrbrightness = 1.35, sdrsaturation = 1.0,
  },
})
hl.config({ render = { cm_auto_hdr = 0 } })

-- NVIDIA VA-API. Not redundant with default/hypr/nvidia.lua: that module gates
-- on o.shell_succeeds(), and os.execute returns ECHILD inside Hyprland's Lua, so
-- it never fires (verified 2026-08-14: LIBVA_DRIVER_NAME absent from a spawned
-- process's environ).
hl.env("LIBVA_DRIVER_NAME", "nvidia")
