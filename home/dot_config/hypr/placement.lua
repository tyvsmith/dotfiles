-- Focus a managed app's window when it is NOT the one hypr/autostart.lua
-- brought up at boot.
--
-- hypr/apps.lua places every autostarted app with a SILENT workspace rule, so
-- login never yanks the session around. This module supplies the other half:
-- deliberately launching one of those apps later still takes you to it.
--
-- Why an event and not a non-silent workspace rule: a static rule cannot tell a
-- boot launch from a manual one, because it only ever sees the window. The exec
-- rule that used to draw that line binds only to windows that kept
-- HL_EXEC_RULE_TOKEN in their own environ or kept the pid Hyprland forked, and
-- Slack and StreamController keep neither -- see hypr/apps.lua for the full
-- account. Deciding at window.open instead of at map time is what makes the
-- distinction expressible at all.
--
-- Hyprland 0.56.2 facts this leans on, each checked on this machine:
--   * window.open fires AFTER static rules have placed the window: the payload
--     already reports the rule's workspace while the active workspace is
--     untouched. Reading placement here is safe and focusing is purely additive.
--   * the payload is userdata, not a table. w.class / w.title / w.address /
--     w.pid / w.floating and w.workspace.id / w.workspace.name all read;
--     w.initialTitle and w.initialClass are nil, and pairs(w) throws.
--   * w.floating is the value AFTER static rules, so it is a usable read of
--     whether the window joined the layout.
--   * hl.dsp.focus({ window = "address:0x..." }) switches to that window's
--     workspace and focuses it -- and warps the pointer to it, which is why this
--     never fires for a window that opened on the workspace you are already on.
--   * hl.get_active_workspace() returns userdata with .id and .name.
--   * hyprland.start does NOT fire on `hyprctl reload` -- the wait-for-sni scope
--     count is unchanged across one, i.e. autostart does not re-run. Arming
--     therefore happens once per session, and a reload deliberately leaves every
--     app in the plain "focus me" state, which is the right answer mid-session.
--
-- Consequence worth knowing: an app that never manages to start at boot stays
-- armed, so the FIRST manual launch of it is silent and the second focuses.
-- That is the deliberate direction to fail in. Disarming on a timer instead
-- hands back the exact login focus-steal this exists to prevent, every time an
-- app is slow to map.

local M = {}

-- Windows of one app map in a burst, and Steam brings up more than one. Keep
-- the app armed a little past its first window so the siblings stay quiet too.
local BOOT_SIBLING_GRACE_MS = 10000

local managed = {} -- class -> true. Rebuilt on every config load.
local armed   = {} -- class -> true, only between hyprland.start and boot window.

--- Declare that hypr/autostart.lua launches this class at boot.
function M.manage(class)
  assert(type(class) == "string" and class ~= "",
    "hypr/placement.lua: manage() needs a class string")
  managed[class] = true
end

--- Decide what a freshly opened window should do. Split out from the event so
--- it can be exercised without a compositor.
--- @return "ignore"|"transient"|"boot"|"here"|"focus"
function M.classify(class, window_ws, active_ws, floating)
  if not class or not managed[class] then return "ignore" end
  -- Whether the window joined the layout is the sharpest signal available for
  -- "is this a window or an overlay". Steam is the reason: its notification
  -- toasts and hover menus are real top-level windows under the app's own class,
  -- and a toast firing while you are elsewhere would otherwise drag you to
  -- workspace 5. Checked before the boot arm so an overlay can never be mistaken
  -- for the boot window and spend it.
  if floating then return "transient" end
  if armed[class] then return "boot" end
  -- Already on the window's workspace, so there is nowhere to take you. Focusing
  -- anyway is not a no-op: the dispatcher warps the pointer to the new window,
  -- which yanks the cursor out of a hover menu the moment it opens. Steam maps
  -- its dropdowns as real windows under the app's own class, so this is the
  -- common case, not an edge one.
  if window_ws and active_ws and window_ws == active_ws then return "here" end
  return "focus"
end

function M.arm_all()
  for class in pairs(managed) do
    armed[class] = true
  end
end

function M.disarm(class)
  armed[class] = nil
end

if hl then
  hl.on("hyprland.start", M.arm_all)

  hl.on("window.open", function(w)
    local class = w and w.class
    local action = M.classify(class, w and w.workspace and w.workspace.id,
      hl.get_active_workspace().id, w and w.floating)

    if action == "ignore" or action == "here" or action == "transient" then
      return
    elseif action == "boot" then
      -- Disarm on a delay rather than now, so the rest of this app's startup
      -- burst is covered by the same decision.
      hl.timer(function() M.disarm(class) end,
        { timeout = BOOT_SIBLING_GRACE_MS, type = "oneshot" })
      return
    end

    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
  end)
end

return M
