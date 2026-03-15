#!/usr/bin/env bash
# Install system prerequisites needed by later chezmoi scripts
# (build tools for Homebrew, xcode CLI tools on macOS, etc.)
#
# This runs before file changes (and before run_onchange_ package installs),
# ensuring the toolchain is ready when brew/pacman/apt scripts fire.

set -euo pipefail

# Already have build tools? Nothing to do.
command -v git &>/dev/null && command -v gcc &>/dev/null && exit 0

echo "==> Installing system prerequisites..."

if [[ "${OSTYPE:-}" == "darwin"* ]]; then
    if ! xcode-select -p &>/dev/null; then
        xcode-select --install
        echo ""
        echo "Xcode Command Line Tools are installing."
        echo "Re-run 'chezmoi apply' when the installation finishes."
        exit 1
    fi
elif command -v rpm-ostree &>/dev/null; then
    echo "Missing build tools on rpm-ostree system" >&2
    echo "  Option 1: distrobox enter <container>"
    echo "  Option 2: sudo rpm-ostree install gcc gcc-c++ make procps-ng curl file git && reboot"
    exit 1
elif [[ -f /etc/debian_version ]]; then
    sudo apt-get update && sudo apt-get install -y build-essential procps curl file git
elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
    sudo dnf install -y gcc gcc-c++ make procps-ng curl file git
elif [[ -f /etc/arch-release ]] || command -v pacman &>/dev/null; then
    sudo pacman -Sy --needed --noconfirm base-devel procps-ng curl file git
else
    echo "Unsupported OS — install git and gcc manually" >&2
    exit 1
fi
