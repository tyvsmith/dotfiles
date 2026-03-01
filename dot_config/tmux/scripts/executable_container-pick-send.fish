#!/usr/bin/env fish
# container-pick-send.fish — Pick a container via fzf, then send the enter
# command to the originating tmux pane (not the popup).
#
# Usage: container-pick-send.fish <pane_id>

set pane_id $argv[1]
if test -z "$pane_id"
    echo "Usage: container-pick-send.fish <pane_id>" >&2
    read -P "Press enter to close..."
    exit 1
end

# Guard: requires distrobox and fzf
if not command -q distrobox
    echo "container-pick-send: distrobox not found" >&2
    read -P "Press enter to close..."
    exit 1
end
if not command -q fzf
    echo "container-pick-send: fzf not found" >&2
    read -P "Press enter to close..."
    exit 1
end

# Get container list, skip header line
set -l db_output (distrobox list --no-color 2>/dev/null | tail -n +2)

if test (count $db_output) -eq 0
    echo "No distrobox containers found"
    echo "Create one with: distrobox create --name <name> --image <image>"
    read -P "Press enter to close..."
    exit 1
end

# Run fzf directly (not inside command substitution from another function)
# This ensures fzf gets the popup's TTY
set -l selected (
    printf '%s\n' $db_output | \
    fzf \
        --header "Select container  [current pane]" \
        --preview 'sh -c '"'"'name=$(echo "$1" | awk -F"|" "{print \$2}" | xargs); echo "$1"; echo "---"; podman inspect --format "Image: {{.Config.Image}}\nCreated: {{.Created}}\nState: {{.State.Status}}" "$name" 2>/dev/null || echo "Container not running - will start on enter"'"'"' -- {}' \
        --prompt "container> " \
        --layout reverse \
        --border rounded \
        --ansi
)

if test -z "$selected"
    exit 0
end

# Extract container name (second column, pipe-delimited)
set -l container_name (echo $selected | awk -F'|' '{print $2}' | string trim)

if test -z "$container_name"
    echo "Could not parse container name" >&2
    read -P "Press enter to close..."
    exit 1
end

# Send the command as keystrokes to the original pane
tmux send-keys -t "$pane_id" "distrobox enter $container_name" Enter
