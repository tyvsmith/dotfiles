#!/usr/bin/env bash
source "${THPM_THEME_ENV:-$HOME/.local/share/thpm/lib/theme-env.sh}"

target="$HOME/.config/tmux/omarchy-powerkit-theme.sh"
shipped="$HOME/.config/omarchy/current/theme/tmux-powerkit.sh"
colors_toml="$HOME/.config/omarchy/current/theme/colors.toml"
themes_dir="$HOME/.config/tmux/plugins/tmux-powerkit/src/themes"
theme_name_file="$HOME/.config/omarchy/current/theme.name"
entry_script="$HOME/.config/tmux/plugins/tmux-powerkit/tmux-powerkit.tmux"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-powerkit/data"

if ! command -v tmux >/dev/null 2>&1; then
    skipped "tmux-powerkit"
fi

if [[ ! -f "$shipped" && ! -f "$colors_toml" ]]; then
    skipped "tmux-powerkit"
fi

theme=$(tr -d '[:space:]' <"$theme_name_file" 2>/dev/null)

# Pick the native variant whose [background] is closest to the omarchy
# theme's primary_background — semantic light/dark match rather than relying
# on variant names (powerkit's rose-pine "main" is dark; omarchy rose-pine
# is light, which actually matches rose-pine "dawn").
pick_variant() {
    local dir="$1" omarchy_bg="${primary_background:-000000}"
    local f vbg best="" best_dist=999999999 d
    local or=$((16#${omarchy_bg:0:2})) og=$((16#${omarchy_bg:2:2})) ob=$((16#${omarchy_bg:4:2}))
    for f in "$dir"/*.sh; do
        [[ -f "$f" ]] || continue
        vbg=$(grep -m1 '\[background\]' "$f" | grep -oE '[0-9a-fA-F]{6}' | head -1)
        [[ -n "$vbg" ]] || continue
        local vr=$((16#${vbg:0:2})) vg=$((16#${vbg:2:2})) vb=$((16#${vbg:4:2}))
        d=$(( (or-vr)*(or-vr) + (og-vg)*(og-vg) + (ob-vb)*(ob-vb) ))
        if (( d < best_dist )); then
            best_dist=$d
            best=$(basename "$f" .sh)
        fi
    done
    printf '%s' "$best"
}

# Resolve which native variant (if any) matches this omarchy theme name.
native_path=""
if [[ -n "$theme" && -d "$themes_dir/$theme" ]]; then
    v=$(pick_variant "$themes_dir/$theme")
    [[ -n "$v" ]] && native_path="$themes_dir/$theme/$v.sh"
elif [[ -n "$theme" && "$theme" == *-* ]] \
    && [[ -f "$themes_dir/${theme%-*}/${theme##*-}.sh" ]]; then
    native_path="$themes_dir/${theme%-*}/${theme##*-}.sh"
fi

mkdir -p "$(dirname "$target")"

# Resolution order: theme-author-shipped → native powerkit theme → generated.
if [[ -f "$shipped" ]]; then
    install -m 644 "$shipped" "$target"
elif [[ -n "$native_path" ]]; then
    install -m 644 "$native_path" "$target"
else
    accent=$(awk -F'[[:space:]]*=[[:space:]]*' \
        '/^accent[[:space:]]*=/{gsub(/"/,"",$2); print $2; exit}' "$colors_toml")
    [[ -z "$accent" ]] && accent="#${normal_blue}"

    cat >"$target" <<EOF
#!/usr/bin/env bash
# Auto-generated from omarchy theme tokens; regenerated on every theme change.
declare -gA THEME_COLORS=(
    [background]="#${primary_background}"

    [statusbar-bg]="#${primary_background}"
    [statusbar-fg]="#${primary_foreground}"

    [session-bg]="${accent}"
    [session-fg]="#${primary_background}"
    [session-prefix-bg]="#${bright_yellow}"
    [session-copy-bg]="#${bright_cyan}"
    [session-search-bg]="#${bright_green}"
    [session-command-bg]="#${bright_magenta}"

    [window-active-base]="#${primary_foreground}"
    [window-active-style]="bold"
    [window-inactive-base]="#${bright_black}"
    [window-inactive-style]="none"
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#${bright_cyan}"

    [pane-border-active]="${accent}"
    [pane-border-inactive]="#${bright_black}"

    [ok-base]="#${bright_black}"
    [good-base]="#${bright_green}"
    [info-base]="#${bright_blue}"
    [warning-base]="#${bright_yellow}"
    [error-base]="#${bright_red}"
    [disabled-base]="#${normal_black}"

    [message-bg]="#${bright_black}"
    [message-fg]="#${primary_foreground}"

    [popup-bg]="#${primary_background}"
    [popup-fg]="#${primary_foreground}"
    [popup-border]="${accent}"

    [menu-bg]="#${primary_background}"
    [menu-fg]="#${primary_foreground}"
    [menu-selected-bg]="#${selection_background}"
    [menu-selected-fg]="#${selection_foreground}"
    [menu-border]="${accent}"
)
EOF
fi

# Invalidate powerkit's derived caches for the custom theme so the next render
# picks up the fresh file (both theme colors and pre-rendered status segments).
rm -f "$cache_dir"/*__custom__*

# Re-pin in case the user picked a different theme via the powerkit selector
# (C-r) since the conf was loaded — omarchy's theme is the source of truth.
if tmux ls >/dev/null 2>&1; then
    tmux set-option -g @powerkit_theme custom
    tmux set-option -g @powerkit_theme_variant custom
    tmux set-option -g @powerkit_custom_theme_path "$target"
    # Re-run powerkit's entry script so it re-establishes the status format
    # strings with the new theme. refresh-client -S marks the bar dirty but
    # doesn't force tmux to re-execute cached `#(...)` format output.
    tmux run-shell "bash '$entry_script'"
    tmux refresh-client -S
fi

success "tmux-powerkit theme refreshed"
