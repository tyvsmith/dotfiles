#!/usr/bin/env bash
# Ensure SSH sockets directory exists for ControlPath
set -euo pipefail

mkdir -p ~/.ssh/sockets
chmod 700 ~/.ssh/sockets
