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
assert(#rules == 15, 'preserve all live rules and exceptions')
for _, rule in ipairs(rules) do
  assert(rule[2].workspace ~= '6 silent', 'games must use ScopeBuddy placement only')
end
assert(rules[1][1] == 'com\\.slack\\.Slack' and rules[1][2].workspace == '4 silent')
assert(rules[4][1].title == 'negative:^Steam Input On-screen Keyboard$')
assert(rules[8][1].class == '^steam$' and rules[8][1].title == '^Steam Big Picture Mode$')
assert(rules[8][2].fullscreen == true)
assert(rules[10][2].no_initial_focus and rules[10][2].float)
assert(rules[15][2].workspace == 'special:hidden silent')
for _, start in ipairs(starts) do start() end
assert(#commands == 8, 'two service commands and six tray apps; Steam stays disabled')
local units = {}
for i = 3, #commands do
  local unit = commands[i]:match('%-u (app%-hypr%-autostart%-%d+%.scope)')
  assert(unit and not units[unit], 'each startup app needs a distinct marked scope')
  units[unit] = true
  assert(commands[i]:find('env HYPR_AUTOSTART=1 wait-for-sni ', 1, true))
end
print('config: rules, startup isolation, and reload checks passed')
