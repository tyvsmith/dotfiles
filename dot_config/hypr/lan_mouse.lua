-- lan_mouse.lua -- swap in a second set of input options while lan-mouse has
-- the cursor on a client, and swap them back on return. Usage: see
-- hypr/input.lua.
--
-- Only lan-mouse knows when the cursor crosses (Hyprland gets no event; the
-- barrier is a persistent 1px layer), so its enter/leave hooks drive the
-- handle and this owns the state. A config reload wipes the VM and re-reads
-- the options together, so nothing goes stale; a reload while on the client
-- just drops client mode until the next crossing.

local M = {}

local DEFAULTS = {
  natural_scroll = true,
  namespace      = "LAN Mouse Sharing", -- lan-mouse's barrier layer namespace
}

--- Start managing input options for one client. Returns a handle with
--- :enter(), :leave(), :active(); bind it to a global so lan-mouse's hooks
--- can reach it through `hyprctl eval`.
function M.setup(opts)
  assert(type(opts) == "table" and type(opts.kb_options) == "string",
    "lan_mouse.setup: opts.kb_options (xkb options to append) is required")

  local KB_OPTIONS = opts.kb_options
  local NATURAL    = opts.natural_scroll
  if NATURAL == nil then NATURAL = DEFAULTS.natural_scroll end
  local NAMESPACE  = opts.namespace or DEFAULTS.namespace

  local base -- input options captured on enter; nil = not on the client

  local function enter()
    if base then return end -- enter can repeat without a leave
    local kb = hl.get_config("input:kb_options") or ""
    base = { kb_options = kb, natural_scroll = hl.get_config("input:natural_scroll") }
    hl.config({ input = {
      kb_options = (kb ~= "" and kb .. "," or "") .. KB_OPTIONS,
      natural_scroll = NATURAL,
    } })
  end

  local function leave()
    if not base then return end
    hl.config({ input = base })
    base = nil
  end

  -- Safety net: lan-mouse drops its barrier layers on `cli deactivate`, exit and
  -- crash, none of which guarantee leave_hook. No barrier => nothing captured.
  -- (An output change also rebuilds them, costing client mode until the next
  -- crossing.)
  hl.on("layer.closed", function(layer)
    if layer.namespace == NAMESPACE then leave() end
  end)

  return {
    enter  = enter,
    leave  = leave,
    active = function() return base ~= nil end,
  }
end

return M
