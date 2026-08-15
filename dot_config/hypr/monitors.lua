-- Monitors, and sticky HDR.
--
-- This file is the whole of hypr-sticky-hdr, natively in Hyprland's Lua config.
-- Ported from ~/Code/hypr-sticky-hdr/contrib/sticky-hdr.lua on 2026-08-14.
--
-- It replaces the ~900-line bash daemon: the socat event subscription, FIFO
-- IPC, flock single-instance guard, debounce/cooldown machinery, monitor
-- id->name remapping, drift reconciler and INI config parser all existed only
-- because an external process cannot see Hyprland's window events. Here
-- Hyprland calls us.
--
-- Two things Hyprland still does not expose, so both states are stated in full:
--   * A monitor's *configured* VRR mode. HL.Monitor.vrr_active is a runtime
--     "is VRR engaged right now" boolean, exactly like hyprctl's .vrr. With
--     vrr=2 (fullscreen-only) it reads false whenever nothing is fullscreen --
--     precisely when a game's window opens -- so inferring from it would write
--     vrr=0 and kill adaptive sync just as you start playing.
--   * Any way to tell the two states apart except by `cm`, which is readable.
-- Monitor rules are whole-record replacements: a field left out reverts to its
-- default, so emitting just cm=hdr would silently drop the panel to 8-bit.

------------------------------------------------------------------------------
-- The two states.
------------------------------------------------------------------------------

-- output/mode/position/scale are deliberately identical to stock monitors.lua
-- ("", preferred, auto, auto) rather than hardcoded, so nothing here is tied to
-- this particular panel. Verified: preferred resolves to 5120x2160@165.06 at
-- scale 1, and the HDR swap round-trips without touching mode or refresh.
--
-- The only real deviation from stock is the colour pipeline -- bitdepth, cm,
-- vrr, sdrbrightness, sdrsaturation -- which has to be stated in full because
-- monitor rules are whole-record replacements.
local OUTPUT = ""

local MONITOR_SDR = {
  output        = OUTPUT,
  mode          = "preferred",
  position      = "auto",
  scale         = "auto",
  bitdepth      = 10,
  cm            = "srgb",
  vrr           = 2,
  sdrbrightness = 1.0,
  sdrsaturation = 1.0,
}

local MONITOR_HDR = {
  output        = OUTPUT,
  mode          = "preferred",
  position      = "auto",
  scale         = "auto",
  bitdepth      = 10,
  cm            = "hdr",
  vrr           = 2,
  sdrbrightness = 1.35,
  sdrsaturation = 1.0,
}

-- No GDK_SCALE here, and it should stay that way. Stock sets GDK_SCALE=2,
-- matching its assumption of a retina-class 2x panel; this display runs at
-- scale 1, so stock's value is wrong for the hardware, not merely a preference.
-- The 3.x monitors.conf commented the same line out.
--
-- Scope, measured 2026-08-14 with GTK3 and GTK4 windows, because it is easy to
-- overstate: on Wayland GDK_SCALE is IGNORED -- GTK takes scale from the
-- compositor and scale_factor stayed 1 with it set. It applies only to GTK on
-- X11/Xwayland, where scale_factor became 2 and a window's logical allocation
-- halved (content drawn twice as large). It pairs with
-- xwayland.force_zero_scaling = true in default/hypr/envs.lua: Hyprland then
-- won't upscale Xwayland surfaces, so on a 2x panel an X11 app would render at
-- half size unless GTK draws at 2x itself.
--
-- Practical effect of omitting it here: nothing visible today (no Xwayland
-- clients), but any GTK app that does land on Xwayland renders at the right
-- size instead of double.

-- Env vars that mark a process as wanting HDR.
local HDR_ENV = {
  "PROTON_ENABLE_HDR=1",
  "DXVK_HDR=1",
  "ENABLE_HDR_WSI=1",
  "HYPR_STICKY_HDR=1",
}

-- Seconds to stay in HDR after the last HDR window closes, so an alt-tab or a
-- brief relaunch does not flap the display. hl.timer takes milliseconds
-- (verified: timeout=2000 fired after 2s).
local COOLDOWN = 2

-- Reload behaviour, since it is not obvious and decides whether this file needs
-- any teardown logic: Hyprland rebuilds the entire Lua state on every config
-- reload. Verified 2026-08-14 -- a counter on _G stays at 1 across repeated
-- `hyprctl reload`. So handlers registered by a previous load are gone with the
-- state that held them, and nothing here can accumulate across reloads.
--
-- Also worth knowing while editing: Hyprland auto-reloads when the file is
-- saved, so a save followed by an explicit `hyprctl reload` evaluates twice.
-- That is two reloads, not one double evaluation.

------------------------------------------------------------------------------

local hdr_windows = {} -- window address -> true
local hdr_count = 0
local cooldown_timer = nil

-- Read /proc/<pid>/environ (NUL-separated) and look for any of HDR_ENV.
local function pid_wants_hdr(pid)
  if not pid or pid <= 0 then return false end
  local f = io.open("/proc/" .. pid .. "/environ", "rb")
  -- Unreadable environ is a real condition, not a "no": a process in another
  -- user namespace, or one that exited between the event and this read.
  -- Treating it as "no" silently is how the bash version missed games.
  if not f then
    print("[sticky-hdr] cannot read /proc/" .. pid .. "/environ -- treating as non-HDR")
    return false
  end
  local blob = f:read("a") or ""
  f:close()
  for _, want in ipairs(HDR_ENV) do
    -- Match a whole NUL-delimited entry so FOO=1 cannot match BARFOO=1.
    if ("\0" .. blob .. "\0"):find("%z" .. want:gsub("%p", "%%%0") .. "%z") then
      return true
    end
  end
  return false
end

local function apply(spec, why)
  print(string.format("[sticky-hdr] %s -> cm=%s sdrbrightness=%s", why, spec.cm, spec.sdrbrightness))
  hl.monitor(spec)
end

local function cancel_cooldown()
  if cooldown_timer then
    -- HL.Timer exposes set_enabled/is_enabled/set_timeout -- there is no
    -- cancel(). Disabling is how a pending oneshot is called off.
    cooldown_timer:set_enabled(false)
    cooldown_timer = nil
  end
end

local function to_hdr()
  cancel_cooldown()
  apply(MONITOR_HDR, "HDR demand started")
end

local function to_sdr_after_cooldown()
  cancel_cooldown()
  cooldown_timer = hl.timer(function()
    cooldown_timer = nil
    if hdr_count == 0 then apply(MONITOR_SDR, "HDR demand ended") end
  end, { timeout = COOLDOWN * 1000, type = "oneshot" })
end

-- Keyed on address and idempotent in both directions, so the startup scan and a
-- subsequent event for the same window cannot double-count.
local function track(win)
  if not win or not win.address then return end
  if hdr_windows[win.address] then return end
  if not pid_wants_hdr(win.pid) then return end
  hdr_windows[win.address] = true
  hdr_count = hdr_count + 1
  if hdr_count == 1 then to_hdr() end
end

local function drop(address)
  if not address or not hdr_windows[address] then return end
  hdr_windows[address] = nil
  hdr_count = hdr_count - 1
  if hdr_count <= 0 then
    hdr_count = 0
    to_sdr_after_cooldown()
  end
end

-- Forget any tracked window that is no longer live. Used for the paths where
-- the event gives us no usable identity.
local function reconcile()
  local live = {}
  for _, win in ipairs(hl.get_windows()) do
    if win.address then live[win.address] = true end
  end
  local stale = {}
  for address in pairs(hdr_windows) do
    if not live[address] then table.insert(stale, address) end
  end
  for _, address in ipairs(stale) do drop(address) end
end

-- Event callbacks receive one HL.Window as userdata (not a table); field access
-- goes through its metatable. Do not add a type(win) == "table" guard.
hl.on("window.open", function(win) track(win) end)

-- Two teardown paths, because neither covers everything. Measured 2026-08-14:
--
--   window.close    win.address is readable and still matches; the window is
--                   still listed by hl.get_windows(). Fires on a normal exit.
--                   Does NOT fire when the process is SIGKILLed.
--   window.destroy  win.address is nil by the time this runs and the window is
--                   already gone from hl.get_windows(), so it cannot say *which*
--                   window died -- but it does fire on an abrupt death.
--
-- Using only window.destroy is what the original contrib/sticky-hdr.lua did, and
-- it can never match an address, so HDR would engage and never release. Using
-- only window.close would strand HDR whenever a game crashes -- the exact case
-- "sticky" is for. So: close for the precise path, destroy to sweep up.
hl.on("window.close", function(win) drop(win and win.address) end)
hl.on("window.destroy", reconcile)

-- A monitor coming back re-applies Hyprland's own rules, wiping whatever we
-- set. Re-assert if a game is still running. This is the entire replacement for
-- the daemon's reconcile loop, which existed only to notice this from outside.
hl.on("monitor.added", function()
  if hdr_count > 0 then apply(MONITOR_HDR, "monitor re-added, re-asserting HDR") end
end)

-- Adopt windows that already exist. The daemon scanned clients at startup; without
-- this, reloading the config mid-game applies SDR and no event is left to undo it.
for _, win in ipairs(hl.get_windows()) do
  track(win)
end

-- Establish the baseline only if nothing already wants HDR.
if hdr_count == 0 then
  hl.monitor(MONITOR_SDR)
end
