#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Hotkeys Cheatsheet
# @raycast.mode fullOutput
# @raycast.packageName Keyboard

echo "── Keyboard Layout ────────────────────────────────────────
Option key = SUPER (AeroSpace / window management)
Command key = Alt (tmux)

── AeroSpace (Option = SUPER) ────────────────────────────
Option + 1–9 / 0       Switch workspace (10 = scratchpad)
Option + Shift + 1–9   Move window to workspace
Option + arrows         Focus window
Option + Shift+arrows   Move window
Option + Tab / S+Tab    Next / prev workspace
Option + W              Close window
Option + F              Fullscreen
Option + T              Toggle floating
Option + J              Toggle split direction
Option + L              Toggle layout
Option + - / =          Resize width
Option + Shift - / =    Resize height
Option + Enter          New Ghostty window
Option + Shift+Enter    New Chrome window
Option + Shift+N        New Zed window
Option + Shift+C        Open Google Calendar
Option + Shift+E        Open Gmail
Option + Shift+G        Open WhatsApp
Option + Shift+M        Open Spotify
Option + Shift+O        Open Obsidian
Option + Shift+F        Open Finder
Option + Shift+/        Open 1Password
Option + Shift+A        Open Claude
Option + Shift+D        LazyDocker in Ghostty
Option + Cmd+Enter      Ghostty + tmux session
Option + Shift+Cmd+B    Chrome incognito
Option + Ctrl+Tab       Former workspace
Option + S              Scratchpad (workspace 10)
Option + Cmd+S          Move window to scratchpad
Option + Ctrl+C         CleanShot all-in-one
Option + Ctrl+L         Lock screen
Option + Ctrl+T         btop in Ghostty
Option + Ctrl+V         Clipboard history (Raycast)
Option + Ctrl+A         Sound preferences
Option + Ctrl+B         Bluetooth preferences
Option + Ctrl+W         Wi-Fi preferences
Option + Ctrl+X         Monologue (dictation)
Option + Ctrl+,         Toggle Do Not Disturb
Option + ,              Toggle Notification Center
Option + Escape         Apple menu (Raycast)
Option + Cmd+Space      Workspace menu
Option + Space          Raycast launcher

── tmux (prefix = Ctrl+Space) ─────────────────────────────
prefix + h / v      Split horizontal / vertical
prefix + x / k      Kill pane / window
prefix + c          New window
prefix + r / R      Rename window / session
prefix + [          Copy mode  (v select, y copy)
Ctrl+Alt+arrows     Navigate panes
Cmd + 1–9           Switch window
Cmd + Left/Right    Prev / next window
Cmd + Up/Down       Prev / next session

── Ghostty (terminal splits & pane nav) ──────────────────
Ctrl+Shift + E          Split down
Ctrl+Shift + O          Split right
Ctrl+Shift + T          New tab
Ctrl+Shift + 1–9        Go to tab 1–9
Ctrl+Shift + Left/Right Prev / next tab
Ctrl+Cmd + arrows       Navigate tmux panes
Ctrl+Cmd+Shift + arrows Resize tmux panes"
