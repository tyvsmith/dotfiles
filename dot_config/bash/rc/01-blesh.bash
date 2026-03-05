# =============================================================================
# ble.sh Configuration
# Syntax highlighting, autosuggestions, and completion for bash
# Replaces fish's built-in highlighting + autosuggestions
# =============================================================================

# Skip if ble.sh isn't loaded
[[ ${BLE_VERSION-} ]] || return 0

# =============================================================================
# Autosuggestions (fish-like ghost text from history)
# =============================================================================
bleopt complete_auto_complete=1
bleopt complete_auto_delay=50
bleopt complete_auto_history=1
# Only use history for auto-suggestions, not programmable completion.
# The "syntax" source triggers registered completion functions on every
# keystroke, which is unusably slow for heavy completers like paru.
# Tab still triggers full programmable completion on demand.
bleopt complete_auto_complete_opts='syntax-disabled'

# =============================================================================
# Tab Completion
# =============================================================================

# --- Menu behavior ---
# When menu is shown, Tab enters menu-complete (navigate candidates).
bleopt complete_menu_complete=1
# Don't auto-insert the selection while navigating — just highlight it.
# User must press RET to accept. This prevents accidentally inserting
# the wrong candidate when arrow-keying through the menu.
bleopt complete_menu_complete_opts=

# --- Menu display ---
# desc: show candidates with type descriptions (like fish)
bleopt complete_menu_style=align-nowrap
bleopt complete_menu_color=on
bleopt complete_menu_color_match=on
bleopt complete_menu_filter=1

# --- Ambiguous/fuzzy completion (like fish) ---
bleopt complete_ambiguous=1

# --- Case-insensitive completion ---
bind 'set completion-ignore-case on'

# --- Show file type indicators in completion menu ---
bind 'set visible-stats on'

# =============================================================================
# Editing & Display
# =============================================================================

# --- Disable noisy markers ---
bleopt exec_errexit_mark=
bleopt exec_elapsed_mark=
bleopt exec_exit_mark=
bleopt prompt_eol_mark='⏎'

# --- Transient prompt ---
# Trim previous prompts to reduce clutter when scrolling back.
# 'same-dir' only trims when directory hasn't changed between commands.
bleopt prompt_ps1_transient='same-dir'

# =============================================================================
# Abbreviations (sabbrev on Enter)
# =============================================================================

# Expand sabbrevs on accept-line. This is cleaner than overriding the
# RET widget because it cooperates with ble.sh's own accept-line logic
# (syntax checking, multiline editing, etc.)
bleopt edit_magic_accept='sabbrev:verify-syntax'

# =============================================================================
# Key Bindings
# =============================================================================

# M-right: accept first word of auto-suggestion (like fish)
# (already default, but be explicit)
ble-bind -m emacs -f M-right 'auto_complete/@end insert-word'

# C-right: accept first WORD (larger units) of auto-suggestion
ble-bind -m emacs -f C-right 'auto_complete/@end insert-cword'

# =============================================================================
# Faces (colors)
# =============================================================================

# Autosuggestion ghost text — dim gray
ble-face -s auto_complete fg=238

# Menu selection — reverse video with a distinct color
ble-face -s menu_complete_selected bg=24,fg=white

# Matching text in menu — bold cyan
ble-face -s menu_complete_match fg=cyan,bold
