#!/usr/bin/env bash

# Only reload if display topology actually changed (monitor added/removed)
CACHE_DIR="$HOME/.cache/sketchybar"
CONFIG_DIR="$HOME/.config/sketchybar"
STATE_FILE="$CACHE_DIR/display_count"

mkdir -p "$CACHE_DIR"

# Compile helper if needed
HAS_EXT_BIN="$CACHE_DIR/has_external_display"
HAS_EXT_SRC="$CONFIG_DIR/plugins/has_external_display.swift"
if [ ! -f "$HAS_EXT_BIN" ] || [ "$HAS_EXT_SRC" -nt "$HAS_EXT_BIN" ]; then
  swiftc "$HAS_EXT_SRC" -o "$HAS_EXT_BIN" 2>/dev/null
fi

CURRENT=$("$HAS_EXT_BIN" 2>/dev/null || echo 0)
PREVIOUS=$(cat "$STATE_FILE" 2>/dev/null || echo "")

# Only reload when external display status actually changed
if [ "$CURRENT" != "$PREVIOUS" ]; then
  echo "$CURRENT" > "$STATE_FILE"
  sketchybar --reload
fi
