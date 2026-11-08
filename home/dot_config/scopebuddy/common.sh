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
    export MANGOHUD=${MANGOHUD:-1}
    export MANGOHUD_CONFIG=${MANGOHUD_CONFIG:-preset=2,fps_limit=$fps_cap}
    # SCB warns on ordinary pre-hook failures; failed HDR preparation must abort.
    SCB_PRE_COMMAND=${SCB_PRE_COMMAND-"scb_display_start || exit 1"}
    SCB_POST_COMMAND=${SCB_POST_COMMAND-scb_display_stop}
}

apply_mode() {
    if (( SCB_GAMEMODE )); then
        mode=session
    fi
    local wrapped_command="game-performance gamemoderun $command"
    source "$SCB_CONFIGDIR/$mode.conf" || exit 1
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
    [[ -n $_scb_display_fps ]] || return 0
    awk -v hz="$_scb_display_fps" -v margin="${1:-0}" 'BEGIN {
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
        if [[ $(timeout 1 hyprctl eval 'assert(launch_hdr.ready(), "HDR outputs are not ready")') == ok ]]; then
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
    reply=$(timeout 3 hyprctl eval "launch_hdr.$1($$)") || return 1
    if [[ $reply != ok ]]; then
        printf 'ScopeBuddy: HDR launch command rejected: %s\n' "$reply" >&2
        return 1
    fi
}
