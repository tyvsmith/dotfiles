package.path = 'home/dot_config/?.lua;' .. package.path
local starts, commands, rules = {}, {}, {}
hl = {
  on = function(event, fn)
    if event == 'hyprland.start' then starts[#starts+1] = fn end
  end,
  exec_cmd = function(command, effects)
    assert(effects == nil, 'autostart must not duplicate workspace rules')
    commands[#commands+1] = command
  end,
}
o = { window = function(match, effects) rules[#rules+1] = {match, effects} end }
dofile('home/dot_config/hypr/autostart.lua')
dofile('home/dot_config/hypr/windows.lua')
assert(#commands == 0, 'config reload must not launch apps')
assert(package.loaded['hypr.apps'] == nil, 'removed registry must not be required')
assert(#rules > 0, 'windows.lua must register rules')
for _, rule in ipairs(rules) do
  assert(rule[2].workspace ~= '6 silent', 'games must use ScopeBuddy placement only')
end

-- Every rule in windows.lua, identified by content (match + the effects that
-- matter), not by position or count, so reordering or adding rules does not
-- break this while dropping or changing one does.
local function same(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function find_rule(match, effects)
  for _, rule in ipairs(rules) do
    if same(match, rule[1]) then
      local ok = true
      for k, v in pairs(effects) do
        if not same(v, rule[2][k]) then ok = false end
      end
      if ok then return rule end
    end
  end
end
local expected = {
  { 'slack on workspace 4', 'com\\.slack\\.Slack', { workspace = '4 silent' } },
  { 'beeper on workspace 4', 'Beeper', { workspace = '4 silent' } },
  { 'vesktop on workspace 4', 'vesktop', { workspace = '4 silent' } },
  { 'steam main window on workspace 5, keyboard excluded',
    { class = '^steam$', title = 'negative:^Steam Input On-screen Keyboard$' }, { workspace = '5 silent' } },
  { 'steamwebhelper on workspace 5', 'steamwebhelper', { workspace = '5 silent' } },
  { 'protonplus on workspace 5', 'com\\.vysp3r\\.ProtonPlus', { workspace = '5 silent' } },
  { 'titled steam windows tile', { class = '^steam$', title = 'negative:^$' }, { tile = true } },
  { 'big picture is fullscreen', { class = '^steam$', title = '^Steam Big Picture Mode$' }, { fullscreen = true } },
  { 'notification toasts float without focus',
    { class = '^steam$', title = '^notificationtoasts_\\d+_desktop$' }, { float = true, no_initial_focus = true } },
  { 'on-screen keyboard floats without stealing focus',
    { class = '^steam$', title = '^Steam Input On-screen Keyboard$' }, { float = true, no_initial_focus = true } },
  { 'untitled steam popups stay focused',
    { class = '^steam$', title = '^$' }, { min_size = { 1, 1 }, stay_focused = true } },
  { 'streamcontroller on workspace 10', 'com\\.core447\\.StreamController', { workspace = '10 silent' } },
  { 'lan mouse on workspace 10', 'de\\.feschber\\.LanMouse', { workspace = '10 silent' } },
  { 'battle.net tiles', { class = '^steam_app_battlenet$', title = '^Battle\\.net$' }, { tile = true } },

}
for _, e in ipairs(expected) do
  assert(find_rule(e[2], e[3]), 'missing window rule: ' .. e[1])
end

for _, start in ipairs(starts) do start() end
assert(#commands == 7, 'hyprpm and six tray apps; Steam and dock stay disabled')
local units = {}
for i = 2, #commands do
  local unit = commands[i]:match('%-u (app%-hypr%-autostart%-%d+%.scope)')
  assert(unit and not units[unit], 'each startup app needs a distinct marked scope')
  units[unit] = true
  assert(commands[i]:find('env HYPR_AUTOSTART=1 wait-for-sni ', 1, true))
end
print('config: rules, startup isolation, and reload checks passed')
