-- Shared launch metadata; environment values are data, never Lua code.
local M = {}

function M.read_proc(pid, name)
  if type(pid) ~= "number" or pid <= 0 or pid % 1 ~= 0 then return nil end
  local file = io.open("/proc/" .. string.format("%.0f", pid) .. "/" .. name, "rb")
  if not file then return nil end
  local content = file:read("a")
  file:close()
  return content
end

-- Chromium can rewrite environ. Its startup scope remains identifiable.
-- Flatpak can change scopes; check surviving launcher ancestors as well.
function M.is_startup(pid)
  local readable = false
  for depth = 1, 32 do
    local env = M.read_proc(pid, "environ")
    if depth == 1 then readable = env ~= nil end
    if env and ("\0" .. env):find("\0HYPR_AUTOSTART=1\0", 1, true) then return true end
    local group = M.read_proc(pid, "cgroup")
    if group and group:match("/app%-hypr%-autostart%-%d+%.scope[/\n]") then return true end
    local status = M.read_proc(pid, "status")
    local parent = status and tonumber(status:match("\nPPid:%s*(%d+)"))
    if not parent or parent <= 1 or parent == pid then break end
    pid = parent
  end
  if readable then return false end
  return nil -- Unknown identity must not steal focus.
end

-- Read each new window's process directly; do not retain recycled PID results.
function M.read(pid)
  local blob = M.read_proc(pid, "environ")
  if not blob then return nil end

  local options = {
    fullscreen = ("\0" .. blob):find("\0HYPR_FULLSCREEN=1\0", 1, true) ~= nil,
    hdr = ("\0" .. blob):find("\0HYPR_HDR=1\0", 1, true) ~= nil,
    dnd = ("\0" .. blob):find("\0HYPR_DND=1\0", 1, true) ~= nil,
  }
  for entry in blob:gmatch("[^%z]+") do
    local target, suffix = entry:match("^HYPR_WORKSPACE=([1-9]%d*)(.*)$")
    if target and #target <= 10 and tonumber(target) <= 2147483647
      and (suffix == "" or suffix == " silent") then
      options.workspace, options.follow = target, suffix ~= " silent"
      break
    end
  end
  return options
end

-- Field 22 identifies a process across PID reuse; zombies no longer own demand.
function M.process_start(pid)
  local stat = M.read_proc(pid, "stat")
  local tail = stat and stat:match("^%d+ %(.+%) (.+)$")
  if not tail then return nil end
  local fields = {}
  for field in tail:gmatch("%S+") do fields[#fields + 1] = field end
  if fields[1] == "Z" or fields[1] == "X" then return nil end
  return fields[20]
end

return M
