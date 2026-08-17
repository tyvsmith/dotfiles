-- lan-mouse: Mac-friendly keyboard/mouse while the cursor is on the Mac client.
-- Called from lan-mouse's hooks (~/.config/lan-mouse/config.toml):
--   enter_hook = "hyprctl eval 'lan_mouse.enter()'"
--   leave_hook = "hyprctl eval 'lan_mouse.leave()'"
-- Only lan-mouse knows when the cursor crosses (Hyprland gets no event; the
-- barrier is a persistent 1px layer), so the hooks trigger and this owns the
-- state. A config reload wipes the VM and re-reads the options together, so
-- nothing goes stale; a reload while on the Mac just drops Mac mode until the
-- next crossing.

-- altwin:swap_alt_win: Alt/Super in the Mac's Option/Cmd positions.
-- custom:printscreen_f13: PrtSc -> F13 (macOS has no PrtSc); defined in
-- ~/.config/xkb/{rules/evdev,symbols/custom}.
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

-- Safety net: lan-mouse drops its barrier layers on `cli deactivate`, exit and
-- crash, none of which guarantee leave_hook. No barrier => nothing captured.
-- (An output change also rebuilds them, costing Mac mode until the next crossing.)
hl.on("layer.closed", function(layer)
  if layer.namespace == LAYER_NAMESPACE then
    lan_mouse.leave()
  end
end)

return lan_mouse
