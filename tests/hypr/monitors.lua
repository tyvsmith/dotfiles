local rules, config = {}, nil
local monitors = {
  { name = 'PF-1', enabled = true, width = 2800, height = 1752, scale = 4/3, x = 1106, y = 2160 },
  { name = 'DP-1', enabled = true, width = 5120, height = 2160, refresh_rate = 165.058,
    scale = 1.25, x = 20, y = 10, transform = 0 },
}
hl = {
  monitor = function(rule) rules[#rules+1] = rule end,
  env = function() end,
  config = function(value) config = value end,
  get_monitors = function() return monitors end,
}
dofile('home/dot_config/hypr/monitors.lua')
assert(rules[1].output == 'DP-1' and rules[1].cm == 'srgb')
assert(config.render.cm_auto_hdr == 0)
lg_hdr(true)
assert(rules[2].output == 'DP-1' and rules[2].cm == 'hdr')
assert(rules[2].scale == 1.25 and rules[2].position == '20x10')
assert(rules[2].mode == '5120x2160@165.058000' and rules[2].vrr == 2)
lg_hdr(false)
assert(rules[3].output == 'DP-1' and rules[3].cm == 'srgb')
assert(rules[3].scale == 1.25 and rules[3].position == '20x10')
table.remove(monitors, 2) -- get_monitors() only returns enabled outputs
lg_hdr(false)
assert(#rules == 3, 'cleanup must not enable a disabled physical output')
assert(not pcall(lg_hdr, true), 'no local game if the LG cannot be prepared')
print('Monitor HDR lifecycle checks passed')
