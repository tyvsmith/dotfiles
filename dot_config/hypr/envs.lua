-- Environment variables. Loaded after default.hypr.omarchy, so these win.

-- NVIDIA VA-API. Not redundant with default/hypr/nvidia.lua: that module gates
-- on o.shell_succeeds(), and os.execute returns ECHILD inside Hyprland's Lua, so
-- it never fires (verified 2026-08-14: LIBVA_DRIVER_NAME absent from a spawned
-- process's environ).
hl.env("LIBVA_DRIVER_NAME", "nvidia")

-- Deliberately not set: NVD_BACKEND=direct (default since libva-nvidia-driver
-- 0.0.12), __GLX_VENDOR_LIBRARY_NAME (GLVND autodetects; forcing it has broken
-- Wayland login), QT_QPA_PLATFORMTHEME=qt6ct (obsolete on Omarchy 4: stock gtk3
-- reports the same dark palette to Kirigami/QtQuick).
