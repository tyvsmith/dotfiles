#!/usr/bin/env bash
# Chezmoi run_onchange script: Install packages from Brewfile
# Assumes Homebrew is already installed (via bootstrap.sh)
# Brewfile hash: {{ include "Brewfile.tmpl" | sha256sum }}

set -euo pipefail

# shellcheck source=/dev/null
DOTFILES_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}"
source "$DOTFILES_DIR/scripts/lib/common.sh"

ensure_brew_in_path
require_cmd brew

# Brewfile is rendered by chezmoi in the home directory
BREWFILE="$HOME/Brewfile"
require_file "$BREWFILE"

brew bundle --file="$BREWFILE"
