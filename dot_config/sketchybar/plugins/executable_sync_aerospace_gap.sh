#!/usr/bin/env bash
# Detect external display for sketchybar clock positioning.
# AeroSpace handles per-monitor outer.top natively via its config, so this
# script no longer patches the gap — it only detects display topology.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
CACHE_DIR="$HOME/.cache/sketchybar"
mkdir -p "$CACHE_DIR"

EXT_BIN="$CACHE_DIR/has_external_display"
EXT_SRC="$CONFIG_DIR/plugins/has_external_display.swift"
if [ ! -f "$EXT_BIN" ] || [ "$EXT_SRC" -nt "$EXT_BIN" ]; then
  swiftc "$EXT_SRC" -o "$EXT_BIN" 2>/dev/null
fi
HAS_EXTERNAL=$("$EXT_BIN" 2>/dev/null || echo 0)
echo "$HAS_EXTERNAL" > /tmp/sketchybar_has_external
