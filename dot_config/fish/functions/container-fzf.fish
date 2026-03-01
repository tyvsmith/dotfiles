# container-fzf: Interactive container picker using fzf
# Lists distrobox containers and enters the selected one.
# Used standalone or called by tmux/zellij integrations.
#
# Flags:
#   --print-only     Print the enter command instead of executing it
#   --running-only   Only show running containers
#   --new-window     Open selection in a new tmux window (tmux only)
#   --split-h        Open selection in a horizontal tmux split (tmux only)
#   --split-v        Open selection in a vertical tmux split (tmux only)
#   --zellij-pane    Open selection in a new zellij pane

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
    argparse 'print-only' 'running-only' 'new-window' 'split-h' 'split-v' 'zellij-pane' 'header=' -- $argv
    or return 1

    # Determine fzf header text
    set -l fzf_header "Select container"
    if set -q _flag_header
        set fzf_header "$_flag_header"
    else if set -q _flag_new_window
        set fzf_header "Select container  [new window]"
    else if set -q _flag_zellij_pane
        set fzf_header "Select container  [new pane]"
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

    # Format for fzf: show NAME | STATUS | IMAGE (skip ID column)
    # Extract just the name for selection
    # Note: fzf uses $SHELL for preview, so we force sh -c for POSIX compat
    set -l selected (
        printf '%s\n' $db_output | \
        fzf \
            --header "$fzf_header" \
            --preview 'sh -c '"'"'name=$(echo "$1" | awk -F"|" "{print \$2}" | xargs); echo "$1"; echo "---"; podman inspect --format "Image: {{.Config.Image}}\nCreated: {{.Created}}\nState: {{.State.Status}}" "$name" 2>/dev/null || echo "Container not running - will start on enter"'"'"' -- {}' \
            --prompt "container> " \
            --height 60% \
            --layout reverse \
            --border rounded \
            --ansi
    )

    if test -z "$selected"
        return 0 # User cancelled
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

    # tmux integrations
    if set -q _flag_new_window
        if test -n "$TMUX"
            tmux new-window -n "$container_name" "distrobox enter $container_name"
            return 0
        end
    end

    if set -q _flag_split_h
        if test -n "$TMUX"
            tmux split-window -h "distrobox enter $container_name"
            return 0
        end
    end

    if set -q _flag_split_v
        if test -n "$TMUX"
            tmux split-window -v "distrobox enter $container_name"
            return 0
        end
    end

    # zellij integration
    if set -q _flag_zellij_pane
        if test -n "$ZELLIJ"
            zellij run --name "$container_name" -- distrobox enter $container_name
            return 0
        end
    end

    # Default: enter the container directly in the current shell
    distrobox enter $container_name
end
