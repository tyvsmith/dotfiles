-- Prototype: local HDR demand survives config reloads and window replacement.
local launch = require("hypr.launch_options")
local M = {}

function M.setup(monitors)
  local registered = {}
  for _, rule in ipairs(monitors) do
    assert(type(rule.output) == "string" and rule.output ~= "",
      "HDR registration requires an explicit output name")
    assert(not registered[rule.output], "duplicate HDR output: " .. rule.output)
    registered[rule.output] = rule.cm or "srgb"
    hl.monitor(rule)
  end

  local function eligible(monitor)
    return monitor and registered[monitor.name] ~= nil
  end
  local runtime = assert(os.getenv("XDG_RUNTIME_DIR"))
  local instance = assert(os.getenv("HYPRLAND_INSTANCE_SIGNATURE"))
  local path = runtime .. "/hypr/" .. instance .. "/hdr-launches"
  local owners = {}
  local file = io.open(path, "r")
  if file then
    for line in file:lines() do
      local pid, started = line:match("^(%d+) (%d+)$")
      if pid then owners[tonumber(pid)] = started end
    end
    file:close()
  end

  local function save()
    local out = assert(io.open(path .. ".tmp", "w"))
    for pid, started in pairs(owners) do
      assert(out:write(string.format("%d %s\n", pid, started)))
    end
    assert(out:close())
    assert(os.rename(path .. ".tmp", path))
  end

  local function wanted()
    local changed = false
    for pid, started in pairs(owners) do
      if launch.process_start(pid) ~= started then
        owners[pid], changed = nil, true
      end
    end
    if changed then save() end
    if next(owners) then return true end
    -- Unwrapped launches can opt in too, but only while their local windows exist.
    for _, window in ipairs(hl.get_windows()) do
      local monitor, workspace = window.monitor, window.workspace
      if window.mapped and not window.hidden and eligible(monitor)
        and workspace and workspace.id > 0 then
        local options = launch.read(window.pid)
        if options and options.hdr then return true end
      end
    end
    return false
  end

  local controller = {}
  function controller.reconcile()
    local enabled = wanted()
    for _, monitor in ipairs(hl.get_monitors()) do
      -- Keep demand while asleep; wait for an awake local output to update the rule.
      if eligible(monitor) and monitor.enabled and monitor.dpms_status
        and monitor.cm ~= (enabled and "hdr" or registered[monitor.name]) then
        -- Merge color management into this output's existing rule; preserve geometry.
        hl.monitor({ output = monitor.name, cm = enabled and "hdr" or registered[monitor.name] })
      end
    end
  end

  function controller.ready()
    local found = false
    for _, monitor in ipairs(hl.get_monitors()) do
      if eligible(monitor) and monitor.enabled and monitor.dpms_status then
        found = true
        if monitor.cm ~= "hdr" then return false end
      end
    end
    return found
  end

  function controller.acquire(pid)
    local started = assert(launch.process_start(pid), "HDR launch process is unavailable")
    owners[pid] = started
    save()
    controller.reconcile()
  end

  function controller.release(pid)
    owners[pid] = nil
    save()
    controller.reconcile()
  end

  for _, event in ipairs({ "config.reloaded", "monitor.added", "window.open",
    "window.destroy", "window.move_to_workspace" }) do
    hl.on(event, controller.reconcile)
  end
  -- No documented DPMS event: also covers missed exits and actual-state drift.
  hl.timer(controller.reconcile, { timeout = 1000, type = "repeat" })
  return controller
end

return M
