#!/usr/bin/env bash
# Bootstrap script for new machines
# Run: curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/chezmoi-fish/bootstrap.sh | bash

set -e

echo "==> Bootstrapping dotfiles..."

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Set up brew in PATH for this script
    if [[ "$OSTYPE" == "darwin"* ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# Install chezmoi if not present
if ! command -v chezmoi &> /dev/null; then
    echo "==> Installing chezmoi..."
    brew install chezmoi
fi

# Initialize and apply dotfiles
# Clones to ~/.local/share/chezmoi and applies
echo "==> Initializing chezmoi..."
chezmoi init --apply https://github.com/tyvsmith/dotfiles.git

echo "==> Done! Restart your shell or run: exec fish"
