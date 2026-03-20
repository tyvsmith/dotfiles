#!/bin/bash
# Open a new Ghostty window without creating a duplicate dock icon.
# If Ghostty is running, use AppleScript to trigger File → New Window.
# If not running, launch it normally.

if pgrep -xq ghostty; then
    osascript -e '
        tell application "System Events"
            tell process "Ghostty"
                click menu item "New Window" of menu "File" of menu bar 1
            end tell
        end tell
        tell application "Ghostty" to activate
    '
else
    open -a Ghostty
fi
