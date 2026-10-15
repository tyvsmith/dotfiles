-- Static app rules place silently; only explicit manual launches follow.
-- HYPR_WORKSPACE overrides app placement. Startup identity has no timeout.
local M = {}
local managed = {}

function M.manage(class)
  assert(type(class) == "string" and class ~= "")
  managed[class] = true
end

local function read_proc(pid, name)
  if type(pid) ~= "number" or pid <= 0 or pid % 1 ~= 0 then return nil end
  local file = io.open("/proc/" .. string.format("%.0f", pid) .. "/" .. name, "rb")
  if not file then return nil end
  local content = file:read("a")
  file:close()
  return content
end

-- Chromium can rewrite environ. Its startup scope remains identifiable.
-- Flatpak can change scopes; check surviving launcher ancestors as well.
local function is_startup(pid)
  local readable = false
  for depth = 1, 32 do
    local env = read_proc(pid, "environ")
    if depth == 1 then readable = env ~= nil end
    if env and ("\0" .. env):find("\0HYPR_AUTOSTART=1\0", 1, true) then return true end
    local group = read_proc(pid, "cgroup")
    if group and group:match("/app%-hypr%-autostart%-%d+%.scope[/\n]") then return true end
    local status = read_proc(pid, "status")
    local parent = status and tonumber(status:match("\nPPid:%s*(%d+)"))
    if not parent or parent <= 1 or parent == pid then break end
    pid = parent
  end
  if readable then return false end
  return nil -- Unknown identity must not steal focus.
end

-- Read each new window's process directly; do not retain recycled PID results.
local function dynamic_destination(pid)
  local blob = read_proc(pid, "environ")
  if not blob then return nil end

  for entry in blob:gmatch("[^%z]+") do
    local target, suffix = entry:match("^HYPR_WORKSPACE=([1-9]%d*)(.*)$")
    if target and #target <= 10 and tonumber(target) <= 2147483647
      and (suffix == "" or suffix == " silent") then
      return target, suffix ~= " silent"
    end
  end
end

-- Return true when dynamic placement owns this event, including silent no-ops.
function M.place_from_env(window)
  if not window or not window.address or not window.workspace then return false end
  local workspace = window.workspace
  if (workspace.id and workspace.id < 0)
    or (workspace.name and workspace.name:match("^special:")) then return true end

  local target, follow = dynamic_destination(window.pid)
  if not target then return false end
  local selector = "address:" .. window.address
  if workspace.id ~= tonumber(target) then
    hl.dispatch(hl.dsp.window.move({
      window = selector, workspace = target, follow = follow,
    }))
  elseif follow then
    local active = hl.get_active_workspace()
    if active and active.id ~= tonumber(target) then
      hl.dispatch(hl.dsp.focus({ window = selector }))
    end
  end
  return true
end

if hl then
  hl.on("window.open", function(w)
    if not w or not w.address or not w.workspace then return end
    if M.place_from_env(w) then return end
    if not managed[w.class] or w.floating then return end
    local active = hl.get_active_workspace()
    if not active or w.workspace.id == active.id then return end
    if is_startup(w.pid) ~= false then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
  end)
end

return M
