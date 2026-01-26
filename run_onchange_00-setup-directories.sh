#!/usr/bin/env bash
# Ensure required directories exist with proper permissions
# Add new directories here as needed - script re-runs when content changes
set -euo pipefail

# SSH control sockets (used by ControlPath in ssh config)
mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets

# Add other tool directories below as needed:
# mkdir -p ~/.local/share/some-tool
# mkdir -p ~/.cache/another-tool
