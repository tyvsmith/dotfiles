# Register game-launch settings without exporting them to the compositor/hooks.
init_game_env() {
    declare -gA _scb_game_env=()
}
game_env() {
    if (( $# != 2 )) || [[ ! $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        printf 'ScopeBuddy: game_env requires NAME VALUE with a valid environment name.\n' >&2
        return 1
    fi
    _scb_game_env["$1"]=$2
    export -n "${1?}"
}

# An explicit game setting wins, then an inherited value, then this default.
game_env_default() {
    if (( $# != 2 )) || [[ ! $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        printf 'ScopeBuddy: game_env_default requires NAME VALUE.\n' >&2
        return 1
    fi
    [[ ${_scb_game_env[$1]+set} ]] && return 0
    game_env "$1" "${!1-$2}"
}

# Compositor HUD policy shared by desktop ScopeBuddy and outer Punktfunk sessions.
configure_mangoapp() {
    unset MANGOHUD_FPS_LIMIT
    export MANGOHUD=0
    export MANGOHUD_CONFIG="read_cfg,${MANGOHUD_CONFIG:+$MANGOHUD_CONFIG,}no_display,toggle_hud=Shift_R+F12,fps_limit=0"
    # Steam mode otherwise substitutes a temporary no_display config.
    export MANGOHUD_CONFIGFILE=${MANGOHUD_CONFIGFILE:-${XDG_CONFIG_HOME:-$HOME/.config}/MangoHud/MangoHud.conf}
}

configure_launch() {
    display_init || return 1
    context=$(get_display_context)
    width=$(get_display_width)
    height=$(get_display_height)
    refresh=$(get_display_fps)
    source "$SCB_CONFIGDIR/$context.conf" || return 1
    load_game_config || return 1
    apply_mode
}

# Shared by native and nested Gamescope; existing sessions keep their own settings.
apply_desktop_defaults() {
    if [[ -n $workspace ]]; then
        export HYPR_WORKSPACE=$workspace
    else
        unset HYPR_WORKSPACE
    fi
    export HYPR_FULLSCREEN=${HYPR_FULLSCREEN-1}
    if (( scb_punktfunk_stream )); then
        export HYPR_HDR=0
        export HYPR_DND=0
    else
        export HYPR_HDR=${HYPR_HDR-1}
        export HYPR_DND=${HYPR_DND-1}
    fi
    # SCB warns on ordinary pre-hook failures; failed HDR preparation must abort.
    SCB_PRE_COMMAND=${SCB_PRE_COMMAND-"scb_display_start || exit 1"}
    SCB_POST_COMMAND=${SCB_POST_COMMAND-scb_display_stop}
}

apply_mode() {
    if (( SCB_GAMEMODE )); then
        mode=session
    fi
    configure_fps || return 1
    source "$SCB_CONFIGDIR/$mode.conf" || return 1

    # SCB evaluates command as shell text; quote each assignment as one argv item.
    local name assignment prefix="env"
    for name in "${!_scb_game_env[@]}"; do
        printf -v assignment '%q' "$name=${_scb_game_env[$name]}"
        prefix+=" $assignment"
    done
    command="$prefix game-performance gamemoderun $command"
    # Upstream skips the pre-hook without Gamescope; native mode still owns HDR.
    if [[ $mode == native ]]; then command="pre_command && $command"; fi
}

# Resolve the cap, game HUD environment, and nested compositor rate/limit args.
configure_fps() {
    fps_cap=${fps_cap-$(get_display_fps_cap "$fps_margin")}
    if [[ ! $fps_cap =~ ^(0|[1-9][0-9]*)$ ]] && { (( ! SCB_GAMEMODE )) || [[ -n $fps_cap ]]; }; then
        printf 'ScopeBuddy: fps_cap must be a nonnegative integer.\n' >&2
        return 1
    fi
    if [[ $mode == session ]]; then
        # A queued assignment must not override SCB's outer-session HUD guard.
        game_env MANGOHUD 0
        return 0
    fi

    local injection=${_scb_game_env[MANGOHUD]-${MANGOHUD-1}} hud_limit=0
    local appearance=${MANGOHUD_CONFIG-}
    # Stock Gamescope can discard its CLI cap during refresh-policy updates.
    fps_limiter=${fps_limiter:-mangohud}
    case $mode:$fps_limiter in
        native:mangohud|gamescope:mangohud)
            hud_limit=$fps_cap
            if [[ $injection == 0 && $fps_cap != 0 ]]; then
                printf 'ScopeBuddy: MANGOHUD=0 disables the FPS limiter; set an in-game limit and fps_limiter=game.\n' >&2
                [[ $mode == gamescope ]] && return 1
            fi
            ;;
        native:game|gamescope:game|gamescope:gamescope) ;;
        *) printf 'ScopeBuddy: unsupported %s fps_limiter: %s\n' "$mode" "$fps_limiter" >&2; return 1 ;;
    esac
    unset MANGOHUD_FPS_LIMIT '_scb_game_env[MANGOHUD_FPS_LIMIT]'

    if [[ $mode == native ]]; then
        appearance=${_scb_game_env[MANGOHUD_CONFIG]-$appearance}
        game_env MANGOHUD "$injection"
        game_env MANGOHUD_CONFIG "read_cfg,${appearance:+$appearance,}fps_limit=$hud_limit"
        return 0
    fi

    if [[ $fps_limiter == mangohud && $injection != 0 ]]; then
        # Mangoapp owns all HUD interaction; this layer only enforces the cap.
        game_env MANGOHUD 1
        game_env MANGOHUD_CONFIG "no_display,fps_limit=$hud_limit,toggle_hud=,toggle_preset=,toggle_fps_limit=,toggle_logging=,reload_cfg="
    else
        game_env MANGOHUD 0
        game_env MANGOHUD_CONFIG "read_cfg,${appearance:+$appearance,}fps_limit=0"
    fi
    configure_mangoapp

    LC_NUMERIC=C printf -v gamescope_refresh '%.0f' "$refresh"
    gamescope_limit_args=""
    if [[ $fps_limiter == gamescope && $fps_cap != 0 ]]; then
        # Matching virtual refresh avoids fixed-refresh divisor rounding.
        gamescope_refresh=$fps_cap
        gamescope_limit_args=" --framerate-limit $fps_cap"
    fi
}

load_game_config() {
    local game_config

    # Read IDs without executing other games' settings; load the first match once.
    for game_config in "$SCB_CONFIGDIR"/games/*.conf; do
        [[ -f $game_config ]] || continue
        if rg -qFx -- "APP_ID=$SCB_APPID" "$game_config"; then
            source "$game_config" || exit 1
            break
        fi
    done
}

# Source once in ScopeBuddy's shell so the exit hook shares cleanup ownership.
# init snapshots the game-facing display; getters never query the system again.
# start registers local HDR demand before launch; stop releases only this launch.

display_init() {
    local status monitors mode relay
    _scb_local_hdr_enabled=0
    _scb_local_hyprland=${HYPRLAND_INSTANCE_SIGNATURE:+1}
    scb_punktfunk_stream=0
    _scb_display_width= _scb_display_height= _scb_display_fps=

    # Upstream also checks other Steam processes; use this launch's environment.
    SCB_GAMEMODE=0
    if [[ ${XDG_CURRENT_DESKTOP:-} == gamescope || -n ${GAMESCOPE_WAYLAND_DISPLAY:-} ]]; then
        SCB_GAMEMODE=1
        # Punktfunk 0.46 writes its child's LIBEI_SOCKET before starting Steam.
        # Match the session, not the presence of another stream on the host.
        if [[ -n ${LIBEI_SOCKET:-} && -n ${XDG_RUNTIME_DIR:-} ]]; then
            for relay in "$XDG_RUNTIME_DIR"/punktfunk-gamescope-ei "$XDG_RUNTIME_DIR"/punktfunk-gamescope-*-ei; do
                [[ -f $relay && -r $relay ]] || continue
                if [[ $(< "$relay") == "$LIBEI_SOCKET" ]]; then
                    scb_punktfunk_stream=1
                    break
                fi
            done
        fi
        # Optional metadata: a game can reuse this session without querying its mode.
        mode=$(_scb_xrandr_mode) || return 0
    elif [[ -n $_scb_local_hyprland ]]; then
        monitors=$(timeout 2 hyprctl -j monitors) || return 1
        # A focused stream selects streaming preferences; otherwise use the local display.
        if jq -e 'any(.[]; .focused == true and .disabled != true and (.name | startswith("PF-")))' <<< "$monitors" >/dev/null &&
            status=$(timeout 2 punktfunk-host ctl status --json 2>/dev/null) &&
            jq -e '.data.active_sessions > 0' <<< "$status" >/dev/null; then
            scb_punktfunk_stream=1
        fi
        mode=$(jq -er --argjson stream "$scb_punktfunk_stream" '
            [.[] | select(.disabled != true) |
                select(if $stream == 1 then .focused == true and (.name | startswith("PF-"))
                       else (.name | startswith("PF-") | not) end)] |
            if $stream == 0 and length > 1 then map(select(.focused == true)) else . end |
            if length == 1 then .[0] else empty end |
            select([.width, .height, .refreshRate] | all(type == "number" and . > 0)) |
            [.width, .height, .refreshRate] | @tsv
        ' <<< "$monitors") || {
            printf 'ScopeBuddy: cannot resolve the active game display (local output or focused stream).\n' >&2
            return 1
        }
    else
        mode=$(_scb_xrandr_mode) || {
            printf 'ScopeBuddy: cannot read the active display mode.\n' >&2
            return 1
        }
    fi
    read -r _scb_display_width _scb_display_height _scb_display_fps <<< "$mode"
}

get_display_context() {
    if (( scb_punktfunk_stream )); then printf 'streaming\n'; else printf 'local\n'; fi
}
get_display_width() { printf '%s\n' "$_scb_display_width"; }
get_display_height() { printf '%s\n' "$_scb_display_height"; }
# Advertised refresh, not measured rendering or encoding throughput.
get_display_fps() { printf '%s\n' "$_scb_display_fps"; }
get_display_fps_cap() {
    [[ -n $refresh ]] || return 0
    awk -v hz="$refresh" -v margin="${1:-0}" 'BEGIN {
        cap = int(hz + 0.5) - margin; print (cap > 0 ? cap : 1)
    }'
}

_scb_xrandr_mode() {
    LC_ALL=C timeout 2 xrandr --current 2>/dev/null | awk '
        $2 == "connected" { output = $1; next }
        $2 == "disconnected" { output = ""; next }
        output != "" && $1 ~ /^[0-9]+x[0-9]+$/ {
            for (i = 2; i <= NF; i++) if ($i ~ /\*/) {
                split($1, size, "x"); hz = $i; gsub(/[*+]/, "", hz)
                if (size[1] > 0 && size[2] > 0 && hz + 0 > 0) {
                    mode = size[1] "\t" size[2] "\t" hz; count++
                }
            }
        }
        END { if (count == 1) print mode; else exit 1 }
    '
}

scb_display_start() {
    # Punktfunk owns streamed outputs; only local launches request HDR.
    (( scb_punktfunk_stream )) && return 0
    [[ -n $_scb_local_hyprland ]] || return 0
    [[ ${HYPR_HDR:-0} == 1 ]] || return 0
    # Mark cleanup ownership first, including a partially failed acquire.
    _scb_local_hdr_enabled=1
    _scb_hdr_launch acquire || return 1
    # Monitor rules commit after the eval reply. Wait before the game probes HDR.
    local attempt
    for attempt in {1..20}; do
        if [[ $(timeout 1 hyprctl eval 'assert(launch_policy.hdr.ready(), "HDR outputs are not ready")') == ok ]]; then
            return 0
        fi
        sleep 0.05
    done
    printf 'ScopeBuddy: Registered outputs did not enter HDR; aborting launch.\n' >&2
    return 1
}

scb_display_stop() {
    if (( _scb_local_hdr_enabled )); then _scb_hdr_launch release; fi
}

_scb_hdr_launch() {
    local reply
    reply=$(timeout 3 hyprctl eval "launch_policy.hdr.$1($$)") || return 1
    if [[ $reply != ok ]]; then
        printf 'ScopeBuddy: HDR launch command rejected: %s\n' "$reply" >&2
        return 1
    fi
}
