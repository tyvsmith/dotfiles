local policy, config
package.loaded["hypr.hdr"] = {
  setup = function(rules) assert(#rules == 1); policy = rules[1]; return { prototype = true } end,
}
hl = {
  env = function() end,
  config = function(value) config = value end,
}
dofile("home/dot_config/hypr/monitors.lua")
assert(policy.output == "DP-1" and policy.position == "0x0" and policy.cm == "srgb")
assert(policy.scale == 1 and policy.vrr == 2)
assert(policy.bitdepth == 10, "use 10-bit output in both SDR and HDR")
assert(config.render.cm_auto_hdr == 0)
assert(launch_hdr.prototype, "monitors.lua owns tracker initialization")
assert(lg_hdr == nil, "remove the LG-specific entry point")
print("Monitor policy: explicit registration, continuous 10-bit, and HDR initialization passed")
