#!/usr/bin/env bash
# Chezmoi run_onchange script: Install Fisher and Fish plugins
# fish_plugins hash: {{ include "dot_config/fish/fish_plugins.tmpl" | sha256sum }}
set -euo pipefail

# shellcheck source=/dev/null
source "${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/scripts/lib/common.sh"

ensure_brew_in_path

# Check if fish is available
require_cmd fish

log "Installing Fisher and plugins..."

# Install Fisher if not present
fish -c '
if not functions -q fisher
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
    fisher install jorgebucaran/fisher
end
fisher update
'
