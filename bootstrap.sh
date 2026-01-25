#!/usr/bin/env bash
# Bootstrap script for new machines
# Run: curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/chezmoi-fish/bootstrap.sh | bash

set -e

echo "==> Bootstrapping dotfiles..."

# Install Homebrew dependencies (git, curl, build tools)
if ! command -v git &> /dev/null || ! command -v gcc &> /dev/null; then
    echo "==> Installing Homebrew prerequisites..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! xcode-select -p &> /dev/null; then
            echo "Installing Xcode Command Line Tools..."
            xcode-select --install
            echo "Please wait for Xcode Command Line Tools installation to complete, then re-run this script."
            exit 0
        fi
    elif command -v rpm-ostree &> /dev/null; then
        echo "⚠️  Missing build tools on rpm-ostree system (Fedora Silverblue/Bazzite/etc)"
        echo ""
        echo "Option 1 (Recommended): Use a distrobox container"
        echo "  distrobox enter <container-name>"
        echo "  # Then run this bootstrap script inside the container"
        echo ""
        echo "Option 2: Install to base system (requires reboot)"
        echo "  sudo rpm-ostree install gcc gcc-c++ make procps-ng curl file git"
        echo "  systemctl reboot"
        echo "  # Then re-run this script after reboot"
        exit 1
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update
        sudo apt-get install -y build-essential procps curl file git
    elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y gcc gcc-c++ make procps-ng curl file git
    elif [[ -f /etc/arch-release ]] || command -v pacman &> /dev/null; then
        sudo pacman -Sy --needed --noconfirm base-devel procps-ng curl file git
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
chezmoi init --apply tyvsmith/dotfiles.git --branch test-fisher-plugins  < /dev/tty

echo "==> Done! Restart your shell or run: exec fish"
