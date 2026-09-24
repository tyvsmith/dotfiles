-- Personal window rules. Loaded after default.hypr.windows, so these win.
--
-- Precedence is the list order in hypr/apps.lua: Hyprland applies matching
-- rules in registration order and the last one wins. No pairs(), and no rule
-- appended after the loop whose correctness depends on where its line sits.
--
-- Static rules are not silent unless the entry says so. Everything autostart.lua
-- launches says so, because the exec rule that used to carry that job cannot be
-- relied on -- see the note in hypr/apps.lua. Placement is therefore only half
-- the story here: hypr/placement.lua focuses any window of those apps that is
-- not the one that came up at boot, so a later launch still takes you to it.

local apps = require("hypr.apps")

for _, app in ipairs(apps.list) do
  -- Fresh table per call. o.window writes .match into the table it is handed,
  -- and app.rules is shared with hypr/autostart.lua through require's cache.
  local rules = {}
  for k, v in pairs(app.rules or {}) do
    rules[k] = v
  end

  if app.workspace then
    rules.workspace = apps.workspace_arg(app, app.silent)
  end

  if next(rules) then
    o.window(app.match, rules)
  end
end
