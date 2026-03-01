# container-fzf: Interactive container picker using fzf
# Lists distrobox containers and enters the selected one.
# Used standalone or called by tmux/zellij integrations.
#
# Flags:
#   --tmux           tmux mode: enter=new window, alt-h=hsplit, alt-v=vsplit
#   --zellij         zellij mode: enter=floating, alt-s=split, alt-t=new tab
#   --print-only     Print the enter command instead of executing it
#   --running-only   Only show running containers
#   --header=TEXT    Override the fzf header text

function container-fzf --description "Interactive distrobox container picker"
    # Guard: requires distrobox and fzf
    if not command -q distrobox
        echo "container-fzf: distrobox not found" >&2
        return 1
    end
    if not command -q fzf
        echo "container-fzf: fzf not found" >&2
        return 1
    end

    # Parse flags
    argparse 'print-only' 'running-only' 'tmux' 'zellij' 'header=' -- $argv
    or return 1

    # Determine fzf header text
    set -l fzf_header "Select container"
    if set -q _flag_header
        set fzf_header "$_flag_header"
    else if set -q _flag_tmux
        set fzf_header "enter: new window | alt-h: hsplit | alt-v: vsplit"
    else if set -q _flag_zellij
        set fzf_header "enter: floating | alt-s: split | alt-t: new tab"
    end

    # Get container list, skip header line
    # distrobox list format: ID | NAME | STATUS | IMAGE
    set -l db_output (distrobox list --no-color 2>/dev/null | tail -n +2)

    if test (count $db_output) -eq 0
        echo "container-fzf: no distrobox containers found" >&2
        echo "Create one with: distrobox create --name <name> --image <image>" >&2
        return 1
    end

    # Filter to running only if requested
    if set -q _flag_running_only
        set db_output (printf '%s\n' $db_output | string match -r '.*Up.*')
        if test (count $db_output) -eq 0
            echo "container-fzf: no running containers" >&2
            return 1
        end
    end

    # Build fzf options
    set -l fzf_opts \
        --header "$fzf_header" \
        --preview 'sh -c '"'"'name=$(echo "$1" | awk -F"|" "{print \$2}" | xargs); echo "$1"; echo "---"; podman inspect --format "Image: {{.Config.Image}}\nCreated: {{.Created}}\nState: {{.State.Status}}" "$name" 2>/dev/null || echo "Container not running - will start on enter"'"'"' -- {}' \
        --prompt "container> " \
        --layout reverse \
        --border rounded \
        --ansi

    # Multi-action modes use --expect to capture which key was pressed
    if set -q _flag_tmux
        set -a fzf_opts --expect "alt-h,alt-v"
    else if set -q _flag_zellij
        set -a fzf_opts --expect "alt-s,alt-t"
    end

    # Run fzf
    set -l fzf_output (printf '%s\n' $db_output | fzf $fzf_opts)

    if test (count $fzf_output) -eq 0
        return 0 # User cancelled
    end

    # With --expect, first line is the key pressed, second is the selection
    # Without --expect, the only line is the selection
    set -l key ""
    set -l selected ""
    if set -q _flag_tmux; or set -q _flag_zellij
        set key $fzf_output[1]
        set selected $fzf_output[2]
    else
        set selected $fzf_output[1]
    end

    if test -z "$selected"
        return 0
    end

    # Extract container name (second column, pipe-delimited)
    set -l container_name (echo $selected | awk -F'|' '{print $2}' | string trim)

    if test -z "$container_name"
        echo "container-fzf: could not parse container name" >&2
        return 1
    end

    # --print-only: just output the command
    if set -q _flag_print_only
        echo "distrobox enter $container_name"
        return 0
    end

    # ── tmux multi-action mode ───────────────────────────────────────
    # All actions run distrobox as the pane/window command directly.
    # The popup closes automatically when this script exits.
    if set -q _flag_tmux
        switch "$key"
            case "alt-h"
                tmux split-window -h -c "#{pane_current_path}" "distrobox enter $container_name"
            case "alt-v"
                tmux split-window -v -c "#{pane_current_path}" "distrobox enter $container_name"
            case ""
                tmux new-window -n "$container_name" "distrobox enter $container_name"
        end
        return 0
    end

    # ── zellij multi-action mode ─────────────────────────────────────
    # Picker pane has close_on_exit=true, so it auto-closes when script exits.
    # All actions launch distrobox as the pane's command directly.
    if set -q _flag_zellij
        switch "$key"
            case "alt-s"
                # Tiled split running distrobox directly
                zellij action toggle-floating-panes
                zellij action new-pane -d down --name "$container_name" -- distrobox enter $container_name
            case "alt-t"
                # New tab via temp layout with UI chrome
                set -l layout_file (mktemp /tmp/zellij-container-XXXXXX.kdl)
                printf 'layout {
    pane size=1 borderless=true {
        plugin location="compact-bar"
    }
    pane command="distrobox" {
        args "enter" "%s"
        name "%s"
    }
    pane size=1 borderless=true {
        plugin location="status-bar"
    }
}\n' $container_name $container_name > $layout_file
                zellij action new-tab --layout "$layout_file" --name "$container_name"
                rm -f "$layout_file"
            case ""
                # Floating pane running distrobox directly
                zellij action new-pane --floating --name "$container_name" -- distrobox enter $container_name
        end
        return 0
    end

    # Default (no multiplexer flag): enter the container in the current shell
    distrobox enter $container_name
end
