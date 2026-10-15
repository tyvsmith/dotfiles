-- Launch with HYPR_WORKSPACE=6 to exercise the real /proc reader.
local file = assert(io.open("/proc/self/stat", "r"))
local pid = tonumber(file:read("a"):match("^(%d+)"))
file:close()
local callback, moved
hl = {
  on = function(event, fn)
    if event == "window.open" then callback = fn end
    return { remove = function() end }
  end,
  dispatch = function(spec) moved = spec end,
  dsp = { window = { move = function(spec) return spec end } },
}
dofile("home/dot_config/hypr/placement.lua")
assert(not moved, "loading must not move a window")
callback({ pid = pid, address = "0xabc", workspace = { id = 1, name = "1" } })
assert(moved and moved.workspace == "6" and moved.window == "address:0xabc")
print("dynamic placement: real /proc marker read passed")
