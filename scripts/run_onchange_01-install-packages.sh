#!/usr/bin/env bash
# Chezmoi run_onchange script: Install packages from Brewfile
# Assumes Homebrew is already installed (via bootstrap.sh)
# Brewfile hash: {{ include "Brewfile" | sha256sum }}

set -euo pipefail

# shellcheck source=/dev/null
DOTFILES_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}"
source "$DOTFILES_DIR/scripts/lib/common.sh"

ensure_brew_in_path
require_cmd brew
require_file "$DOTFILES_DIR/Brewfile"

brew bundle --file="$DOTFILES_DIR/Brewfile"
