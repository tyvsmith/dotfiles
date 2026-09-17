#!/bin/bash
# launch-here.sh — launch/activate a macOS app and place its window on the
# OmniWM workspace that was focused when the hotkey fired.
#
# Why this exists: skhd hotkeys launch apps with `open`, which *activates* an
# app's existing window. macOS raises that window on whatever workspace it
# already lives on, and OmniWM follows focus there — so a hotkey pressed on
# workspace 4 yanks you to the workspace where the app already has windows
# (e.g. a new Ghostty window lands next to the other Ghostty windows on ws1).
#
# This wrapper records the focused workspace, runs the launch command, finds
# the relevant window, then relocates it to where you were.
#
# Two modes, because the safe target differs:
#   --new-window : the command spawns a NEW window (Ghostty, browser --new-window).
#                  Only a genuinely new window is relocated; existing windows are
#                  never touched. If no new window appears, nothing happens.
#   (default)    : the command activates a single-window app (Slack, Spotify,
#                  PWAs, Finder…). The app's focused/only window is relocated.
#
# Requires OmniWM IPC (Settings → enable IPC). If omniwmctl can't reach the
# daemon, the launch command is run unchanged so hotkeys never break.
#
# Usage:
#   launch-here.sh [--new-window] <bundle-id> -- <launch-command...>

set -u

CTL=/Applications/OmniWM.app/Contents/MacOS/omniwmctl

new_window=0
if [ "${1:-}" = "--new-window" ]; then new_window=1; shift; fi
bundle="${1:?usage: launch-here.sh [--new-window] <bundle-id> -- <command...>}"; shift
[ "${1:-}" = "--" ] && shift
# Remaining args ("$@") are the launch command.

# No IPC reachable → just launch and get out of the way.
if ! "$CTL" ping >/dev/null 2>&1; then
    exec "$@"
fi

q() { "$CTL" query "$@" --format json 2>/dev/null; }

# Workspace the user is looking at right now. rawName drives `workspace
# focus-name`; number drives `command move-to-workspace` (1-indexed, matches
# the display number). For numeric workspaces these are identical ("5").
home=$(q active-workspace)
home_name=$(printf '%s' "$home" | jq -r '.result.payload.workspace.rawName // empty')
home_num=$(printf '%s'  "$home" | jq -r '.result.payload.workspace.number // empty')

# Snapshot the app's existing window ids (used by --new-window mode to spot a
# brand-new one).
before=$(q windows --bundle-id "$bundle" | jq -r '.result.payload.windows[]?.id' | sort)

# Fire the launch / activation.
"$@" &

# Find the window to relocate.
target=""
for _ in $(seq 1 30); do
    sleep 0.1
    now=$(q windows --bundle-id "$bundle")
    [ -z "$now" ] && continue

    if [ "$new_window" -eq 1 ]; then
        # Only a window id that wasn't present before counts.
        target=$(printf '%s\n' "$now" | jq -r '.result.payload.windows[]?.id' \
            | sort | comm -13 <(printf '%s\n' "$before") - | head -1)
    else
        # Activation: take the app's focused window, else its first window.
        target=$(printf '%s\n' "$now" | jq -r '
            (.result.payload.windows // [])
            | (map(select(.isFocused)) + .) | .[0].id // empty')
    fi
    [ -n "$target" ] && break
done

# Nothing to act on (creation failed, app never showed a window) → leave as-is.
[ -z "$target" ] && exit 0

# Where did the target window end up?
target_ws=$(q windows --bundle-id "$bundle" \
    | jq -r --arg id "$target" '
        .result.payload.windows[]? | select(.id==$id) | .workspace.rawName // empty')

# Already on the workspace we started from → nothing to do.
[ -n "$home_name" ] && [ "$target_ws" = "$home_name" ] && exit 0

# Relocate the window to the workspace we launched from:
#   focus it (switches view to its workspace) → move it to home → view home →
#   focus it again. move-to-workspace acts on the focused window and does not
#   follow, so we switch the view back explicitly.
"$CTL" window focus "$target" >/dev/null 2>&1
[ -n "$home_num" ]  && "$CTL" command move-to-workspace "$home_num" >/dev/null 2>&1
[ -n "$home_name" ] && "$CTL" workspace focus-name "$home_name" >/dev/null 2>&1
"$CTL" window focus "$target" >/dev/null 2>&1
