# =============================================================================
# fzf Integration (via ble.sh contrib)
# Provides: C-t (file search), M-c (cd into directory), ** Tab triggers,
# and enhanced completion with fzf popup for candidate selection.
# C-r (history) is handled by atuin (loaded after this in 04-atuin.bash).
# =============================================================================

# Skip if ble.sh or fzf aren't available
[[ ${BLE_VERSION-} ]] || return 0
command -v fzf &>/dev/null || return 0

# --- fzf defaults ---
# Use fd for file search if available (respects .gitignore, faster than find)
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# Preview with bat for files, eza for directories
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || eza --tree --level=2 --icons=auto {} 2>/dev/null'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

export FZF_ALT_C_OPTS="
  --preview 'eza --tree --level=2 --icons=auto --color=always {} 2>/dev/null'"

# --- Load ble.sh fzf integration ---
# Uses blesh-contrib wrappers that properly integrate fzf with ble.sh's
# line editor instead of fzf's default bash integration (which conflicts
# with ble.sh's line editing).
# Completion deferred (-d) for faster startup; key bindings loaded eagerly
# so atuin (loaded next in 04-atuin.bash) can override C-r for history.
ble-import -d integration/fzf-completion
ble-import integration/fzf-key-bindings
