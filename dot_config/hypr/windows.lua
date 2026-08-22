-- Personal window rules. Loaded after default.hypr.windows, so these win.
--
-- Workspace rules are NOT silent on purpose: a launcher start or a tray re-show
-- should switch to the app. Boot launches stay quiet via the exec rule in
-- hypr/autostart.lua, which reads the same placements and adds "silent".

for _, p in pairs(require("hypr.placements")) do
  o.window(p.match, { workspace = tostring(p.workspace) })
end
