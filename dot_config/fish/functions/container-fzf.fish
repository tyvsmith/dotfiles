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
#   --zellij         Zellij mode: multi-action picker (enter/ctrl-s/ctrl-t)

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
    argparse 'print-only' 'running-only' 'new-window' 'split-h' 'split-v' 'zellij' 'header=' -- $argv
    or return 1

    # Determine fzf header text
    set -l fzf_header "Select container"
    if set -q _flag_header
        set fzf_header "$_flag_header"
    else if set -q _flag_new_window
        set fzf_header "Select container  [new window]"
    else if set -q _flag_zellij
        set fzf_header "enter: current pane | alt-s: split | alt-t: new tab"
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

    # In zellij mode, use --expect to capture which key was pressed
    if set -q _flag_zellij
        set -a fzf_opts --expect "alt-s,alt-t"
    end

    # Run fzf
    set -l fzf_output (printf '%s\n' $db_output | fzf $fzf_opts)

    if test (count $fzf_output) -eq 0
        return 0 # User cancelled
    end

    # In zellij mode, first line is the key pressed, second is the selection
    # In normal mode, the only line is the selection
    set -l key ""
    set -l selected ""
    if set -q _flag_zellij
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

    # zellij multi-action mode
    # Picker pane has close_on_exit=true, so it auto-closes when script exits.
    # Uses --in-place or -- COMMAND to launch distrobox as the pane's process
    # (no leftover shell command text, clean pane title).
    if set -q _flag_zellij
        switch "$key"
            case "alt-s"
                # Tiled split running distrobox directly
                zellij action toggle-floating-panes
                zellij action new-pane -d down --name "$container_name" -- distrobox enter $container_name
            case "alt-t"
                # New tab: generate a temp layout with the distrobox command, open as tab
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
                # Current pane: send distrobox command to the original pane
                zellij action toggle-floating-panes
                sleep 0.3
                zellij action write-chars "distrobox enter $container_name"
                zellij action write 10
        end
        return 0
    end

    # Default: enter the container directly in the current shell
    distrobox enter $container_name
end
