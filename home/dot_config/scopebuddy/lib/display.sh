# Source once in ScopeBuddy's shell so the exit hook shares cleanup ownership.
# init snapshots the launch target and exposes scb_punktfunk_stream plus stream dimensions.
# start prepares that target before launch; stop restores only HDR enabled by this launch.

scb_display_init() {
    local status monitors mode
    _scb_local_hdr_enabled=0
    _scb_local_hyprland=${HYPRLAND_INSTANCE_SIGNATURE:+1}
    scb_punktfunk_stream=0
    scb_punktfunk_output=
    scb_stream_width=0 scb_stream_height=0 scb_stream_fps=0

    command -v punktfunk-host >/dev/null && command -v hyprctl >/dev/null || return 0
    status=$(timeout 2 punktfunk-host ctl status --json 2>/dev/null) || return 0
    jq -e '.data.active_sessions > 0' <<< "$status" >/dev/null 2>&1 || return 0
    monitors=$(timeout 2 hyprctl -j monitors 2>/dev/null) || return 0
    mode=$(jq -er '
        [.[] | select(.focused == true and .disabled != true and (.name | startswith("PF-")))] |
        if length == 1 then .[0] else empty end |
        select(.width > 0 and .height > 0 and .refreshRate > 0) |
        [.name, .width, .height, (.refreshRate | round)] | @tsv
    ' <<< "$monitors" 2>/dev/null) || return 0
    read -r scb_punktfunk_output scb_stream_width scb_stream_height scb_stream_fps <<< "$mode"
    scb_punktfunk_stream=1
}

scb_display_start() {
    if (( scb_punktfunk_stream )); then
        _scb_prepare_punktfunk
        return $?
    fi
    [[ -n $_scb_local_hyprland ]] || return 0
    _scb_set_local_hdr true || return 1
    _scb_local_hdr_enabled=1
    # Monitor rules commit after the eval reply. Wait before the game probes HDR.
    local attempt
    for attempt in {1..20}; do
        if timeout 1 hyprctl -j monitors | jq -e 'any(.[]; .name == "DP-1" and .colorManagementPreset == "hdr")' >/dev/null; then
            return 0
        fi
        sleep 0.05
    done
    printf 'ScopeBuddy: LG did not enter HDR; aborting launch.\n' >&2
    return 1
}

scb_display_stop() {
    if (( _scb_local_hdr_enabled )); then _scb_set_local_hdr false; fi
}

_scb_set_local_hdr() {
    local reply
    reply=$(timeout 3 hyprctl eval "lg_hdr($1)") || return 1
    if [[ $reply != ok ]]; then
        printf 'ScopeBuddy: LG HDR command rejected: %s\n' "$reply" >&2
        return 1
    fi
}

# Work around headless outputs advertising max luminance below reference white.
# Preserve valid peaks, even below 1000. This fallback is not client calibration; 0 opts out.
_scb_prepare_punktfunk() {
    local peak=${SCB_PUNKTFUNK_HDR_MAX_LUMINANCE:-1000} monitors rule reply metadata decision
    [[ $peak == 0 ]] && return 0
    if [[ ! $peak =~ ^[1-9][0-9]{0,4}$ ]] || (( peak > 10000 )); then
        printf 'ScopeBuddy: invalid streaming HDR luminance: %s\n' "$peak" >&2
        return 1
    fi
    monitors=$(timeout 2 hyprctl -j monitors) || return 1
    decision=$(jq -er --arg output "$scb_punktfunk_output" '
        [.[] | select(.name == $output and .disabled != true)] |
        if length != 1 then error("streaming output disappeared") else .[0] end |
        if .colorManagementPreset == "hdr" or .colorManagementPreset == "hdredid"
        then "hdr" else "skip" end
    ' <<< "$monitors") || return 1
    [[ $decision == skip ]] && return 0
    # Monitor JSON omits the peak. Read the same Wayland luminance event Wine sees.
    metadata=$(scb-output-luminance "$scb_punktfunk_output") || {
        printf 'ScopeBuddy: cannot read HDR metadata; leaving output unchanged.\n' >&2
        return 1
    }
    decision=$(jq -er --arg output "$scb_punktfunk_output" --argjson monitors "$monitors" --argjson peak "$peak" '
        def fallback($white):
            if $peak <= $white then error("HDR fallback must exceed reference white") else "fallback" end;
        (.reference_luminance // ($monitors[] | select(.name == $output) | .sdrMaxLuminance) // 203) as $white |
        if ($white | type) != "number" or $white <= 0 then error("invalid reference white")
        elif .max_luminance == null then fallback($white)
        elif .max_luminance <= $white then fallback($white) else "preserve" end
    ' <<< "$metadata") || return 1
    [[ $decision == preserve ]] && return 0
    # Re-check that the output is still HDR; update only its peak on the existing rule.
    monitors=$(timeout 2 hyprctl -j monitors) || return 1
    rule=$(jq -er --arg output "$scb_punktfunk_output" --argjson peak "$peak" '
        [.[] | select(.name == $output and .disabled != true)] |
        if length != 1 then error("streaming output disappeared") else .[0] end |
        if .colorManagementPreset != "hdr" and .colorManagementPreset != "hdredid"
        then "skip" else
            "hl.monitor({output=" + (.name | tojson) + ",max_luminance=" + ($peak | tostring) + "})"
        end
    ' <<< "$monitors") || return 1
    [[ $rule == skip ]] && return 0
    reply=$(timeout 3 hyprctl eval "$rule") || return 1
    # hyprctl can return zero even when Lua rejects a rule.
    if [[ $reply != ok ]]; then
        printf 'ScopeBuddy: HDR override rejected: %s\n' "$reply" >&2
        return 1
    fi
    # The eval reply precedes the compositor's new Wayland image description.
    local attempt
    for attempt in {1..10}; do
        metadata=$(scb-output-luminance "$scb_punktfunk_output") || return 1
        if jq -e '
            .reference_luminance > 0 and .max_luminance > .reference_luminance
        ' <<< "$metadata" >/dev/null; then
            return 0
        fi
        sleep 0.05
    done
    printf 'ScopeBuddy: stream HDR metadata did not become valid; aborting launch.\n' >&2
    return 1
}

