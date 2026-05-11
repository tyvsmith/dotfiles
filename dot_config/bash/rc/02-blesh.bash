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

# Override omarchy's inputrc TAB binding. Omarchy sets "TAB: menu-complete"
# (readline), which ble.sh imports via its inputrc reconstruction. This causes
# TAB to cycle through candidates one-by-one instead of showing a menu.
# Restore ble.sh's "complete" widget which: first TAB inserts common prefix +
# shows menu, second TAB enters menu-complete for navigation.
ble-bind -m emacs -f C-i complete
ble-bind -m emacs -f TAB complete

# =============================================================================
# Bash 5.3+ compgen -V workaround
# =============================================================================

# On bash 5.3+, ble.sh uses `compgen -V compgen` to store completion results
# in an array variable. It then serializes this array via `writearray` which
# calls `declare -p compgen | awk`. However, the `compgen` variable set by
# `compgen -V` is not visible to `declare -p` in certain deep call stacks,
# causing all but the first completion candidate to be silently dropped.
#
# Workaround: After the completion library loads, patch the serialization
# function to use direct `printf` expansion of the array instead of the
# `declare -p | awk` pipeline. This only applies to the bash 5.3+ array
# code path and falls back to the original for entries containing newlines.
if ((_ble_bash >= 50300)); then
  blehook/eval-after-load complete '
    eval "_ble_user_orig_filter_and_split() $(declare -f ble/complete/progcomp/.filter-and-split-compgen | tail -n +2)"

    function ble/complete/progcomp/.filter-and-split-compgen {
      if [[ :$2: == *:array:* ]]; then
        local _entry _has_nl=
        for _entry in "${compgen[@]}"; do
          [[ $_entry == *$'\''\n'\''* ]] && { _has_nl=1; break; }
        done
        if [[ ! $_has_nl ]]; then
          local compgen
          compgen=$(printf '\''%s\n'\'' "${compgen[@]}")
          _ble_user_orig_filter_and_split "$1" "${2/array/}"
          return "$?"
        fi
      fi
      _ble_user_orig_filter_and_split "$@"
    }
  '
fi

# =============================================================================
# Faces (colors)
# =============================================================================

# Autosuggestion ghost text — dim gray
ble-face -s auto_complete fg=238

# Menu selection — reverse video with a distinct color
ble-face -s menu_complete_selected bg=24,fg=white

# Matching text in menu — bold cyan
ble-face -s menu_complete_match fg=cyan,bold
