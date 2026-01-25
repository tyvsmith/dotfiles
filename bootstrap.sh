#!/usr/bin/env bash
# Bootstrap script for new machines
# Run: curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/chezmoi-fish/bootstrap.sh | bash

set -e

echo "==> Bootstrapping dotfiles..."

# Install Homebrew dependencies (git, curl, build tools)
if ! command -v git &> /dev/null || ! command -v gcc &> /dev/null; then
    echo "==> Installing Homebrew prerequisites..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt-get update
        sudo apt-get install -y build-essential procps curl file git
    elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y gcc gcc-c++ make procps-ng curl file git
    fi
fi

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
chezmoi init --apply --branch chezmoi-fish https://github.com/tyvsmith/dotfiles.git

echo "==> Done! Restart your shell or run: exec fish"
