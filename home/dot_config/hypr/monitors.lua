-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all
--
-- Kept on their own lines: `omarchy hyprland monitor scaling` rewrites these two
-- by regex. GDK_SCALE must stay 1 on this scale-1 5120x2160 panel; stock's 2
-- doubles every XWayland/CEF app (Spotify).
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- SDR desktop baseline. ScopeBuddy calls lg_hdr(true/false) around local games.
local lg = {
  output = "DP-1", mode = "preferred", position = "0x0",
  scale = omarchy_monitor_scale, vrr = 2,
  cm = "srgb", sdrbrightness = 1.35, sdrsaturation = 1.0,
}
hl.monitor(lg)
hl.config({ render = { cm_auto_hdr = 0 } })

-- Runtime-only: preserve layout/scale, touch only the active LG, never wake it.
function lg_hdr(enabled)
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name == lg.output then
      local rule = {}
      for key, value in pairs(lg) do rule[key] = value end
      rule.mode = string.format("%dx%d@%.6f", monitor.width, monitor.height, monitor.refresh_rate)
      rule.position = string.format("%dx%d", monitor.x, monitor.y)
      rule.scale = monitor.scale
      rule.transform = monitor.transform
      rule.cm = enabled and "hdr" or "srgb"
      hl.monitor(rule)
      return
    end
  end
  assert(not enabled, "LG DP-1 is unavailable for local HDR")
end

-- NVIDIA VA-API. Not redundant with default/hypr/nvidia.lua: that module gates
-- on o.shell_succeeds(), and os.execute returns ECHILD inside Hyprland's Lua, so
-- it never fires (verified 2026-08-14: LIBVA_DRIVER_NAME absent from a spawned
-- process's environ).
hl.env("LIBVA_DRIVER_NAME", "nvidia")
