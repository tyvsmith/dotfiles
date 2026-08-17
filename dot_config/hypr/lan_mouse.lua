-- lan-mouse: Mac-friendly keyboard/mouse while the cursor is on the Mac client.
--
-- Called from lan-mouse's per-client hooks (~/.config/lan-mouse/config.toml):
--   enter_hook = "hyprctl eval 'lan_mouse.enter()'"
--   leave_hook = "hyprctl eval 'lan_mouse.leave()'"
--
-- Only lan-mouse knows when the cursor crosses to the client -- Hyprland gets
-- no event, the capture barrier is a persistent 1px layer -- so the hooks are
-- the trigger and this module owns the state. State is an upvalue in
-- Hyprland's Lua VM: a config reload wipes the VM and re-reads input options
-- from these files, so both reset together and nothing goes stale. Cost: a
-- reload while on the Mac drops Mac mode until the next crossing.

-- altwin:swap_alt_win     Alt/Super land in the Mac's Option/Cmd positions.
-- custom:printscreen_f13  Print Screen -> F13; macOS has no PrtSc. Defined in
--                         ~/.config/xkb/{rules/evdev,symbols/custom}.
local MAC_KB_ADDITIONS = "altwin:swap_alt_win,custom:printscreen_f13"
local LAYER_NAMESPACE = "LAN Mouse Sharing"

local base -- input options captured on enter; nil = not on the Mac

lan_mouse = {}

function lan_mouse.enter()
  if base then return end -- enter can repeat without a leave
  local kb = hl.get_config("input:kb_options") or ""
  base = { kb_options = kb, natural_scroll = hl.get_config("input:natural_scroll") }
  hl.config({ input = {
    kb_options = (kb ~= "" and kb .. "," or "") .. MAC_KB_ADDITIONS,
    natural_scroll = true,
  } })
end

function lan_mouse.leave()
  if not base then return end
  hl.config({ input = base })
  base = nil
end

-- Safety net. lan-mouse tears its barrier layers down on `cli deactivate`, on
-- exit, and (courtesy of the compositor) on crash; leave_hook is not guaranteed
-- for any of those. No barrier => nothing is capturing => not on the Mac.
-- lan-mouse also rebuilds the layers on an output change, which fires this
-- while still on the Mac -- costs Mac mode until the next crossing, no worse.
hl.on("layer.closed", function(layer)
  if layer.namespace == LAYER_NAMESPACE then
    lan_mouse.leave()
  end
end)

return lan_mouse
