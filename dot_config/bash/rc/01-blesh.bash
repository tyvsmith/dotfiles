# =============================================================================
# ble.sh Configuration
# Syntax highlighting, autosuggestions, and abbreviations for bash
# Replaces fish's built-in highlighting + autosuggestions
# =============================================================================

# Skip if ble.sh isn't loaded
[[ ${BLE_VERSION-} ]] || return 0

# --- Autosuggestion style (fish-like ghost text) ---
bleopt complete_auto_complete=1
bleopt complete_auto_delay=50
bleopt complete_auto_history=1
# Only use history for auto-suggestions, not programmable completion.
# The "syntax" source triggers registered completion functions on every
# keystroke, which is unusably slow for heavy completers like paru.
# Tab still triggers full programmable completion on demand.
bleopt complete_auto_complete_opts='syntax-disabled'

# --- Menu completion (fish-like: show candidate list, navigate with Tab) ---
bleopt complete_menu_complete=1
bleopt complete_menu_complete_opts=
bleopt complete_menu_filter=1

# --- Ambiguous completion (fuzzy matching like fish) ---
bleopt complete_ambiguous=1

# --- Disable noisy markers ---
bleopt exec_errexit_mark=
bleopt exec_elapsed_mark=
bleopt exec_exit_mark=
bleopt prompt_eol_mark='⏎'

# --- Expand abbreviations on Enter (like fish) ---
# By default ble-sabbrev only triggers on Space. This widget expands
# any sabbrev first, then always accepts the line.
function ble/widget/sabbrev-accept {
  ble/widget/sabbrev-expand
  ble/widget/accept-line
}
ble-bind -m emacs -f C-m sabbrev-accept
ble-bind -m emacs -f RET sabbrev-accept

# --- Autosuggestion face (dimmed, like fish) ---
ble-face -s auto_complete fg=238
