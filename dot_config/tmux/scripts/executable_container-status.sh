#!/usr/bin/env bash
# container-status.sh — Show the container name for the active tmux pane
# Returns the CONTAINER_ID if the active pane is inside a distrobox/toolbox,
# or empty string if on the host. Used in tmux status-right.

set -euo pipefail

PANE_PID=$(tmux display-message -p '#{pane_pid}' 2>/dev/null)
[ -z "$PANE_PID" ] && exit 0

# Walk the pane's process tree looking for CONTAINER_ID
for pid in $(pgrep -P "$PANE_PID" 2>/dev/null || true) $PANE_PID; do
    if [ -r "/proc/$pid/environ" ]; then
        cid=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^CONTAINER_ID=//p' | head -1)
        if [ -n "$cid" ]; then
            echo "󰏖 $cid"
            exit 0
        fi
    fi
done
