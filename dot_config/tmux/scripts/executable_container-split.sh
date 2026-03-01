#!/usr/bin/env bash
# container-split.sh — Container-aware tmux split
# If the current pane is inside a distrobox container, the new split
# automatically enters the same container. Otherwise, opens a normal shell.
#
# Usage: container-split.sh [-h|-v]
#   -h  horizontal split (side by side)
#   -v  vertical split (top/bottom)

set -euo pipefail

SPLIT_DIR="${1:--h}"

# Get the active pane's PID, then walk its child processes to find CONTAINER_ID
PANE_PID=$(tmux display-message -p '#{pane_pid}')
CONTAINER_ID=""

# Check the pane's environment for CONTAINER_ID
# Walk the process tree to find a shell that has CONTAINER_ID set
if [ -n "$PANE_PID" ]; then
    # Try to read CONTAINER_ID from any child process of the pane
    for pid in $(pgrep -P "$PANE_PID" 2>/dev/null) $PANE_PID; do
        if [ -r "/proc/$pid/environ" ]; then
            cid=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep '^CONTAINER_ID=' | head -1 | cut -d= -f2-)
            if [ -n "$cid" ]; then
                CONTAINER_ID="$cid"
                break
            fi
        fi
    done
fi

if [ -n "$CONTAINER_ID" ]; then
    # Inside a container — new split enters the same container
    tmux split-window "$SPLIT_DIR" -c "#{pane_current_path}" "distrobox enter $CONTAINER_ID"
else
    # On host — normal split
    tmux split-window "$SPLIT_DIR" -c "#{pane_current_path}"
fi
