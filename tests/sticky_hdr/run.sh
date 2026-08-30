#!/usr/bin/env bash
# Behavior tests for dot_config/hypr/sticky_hdr.lua against a mock hl API.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

LUA=$(command -v lua5.4 || command -v lua) || { echo "no lua interpreter found"; exit 1; }

rt=$(mktemp -d)
trap 'rm -rf "$rt"' EXIT

HYPR_STICKY_HDR=1 XDG_RUNTIME_DIR="$rt" "$LUA" test.lua
