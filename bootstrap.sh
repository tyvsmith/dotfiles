#!/usr/bin/env bash
# Bootstrap script for new machines
# Run: curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/bootstrap.sh | bash
#
# Environment variables:
#   DOTFILES_BRANCH       - Git branch to use (default: main)
#   CHEZMOI_IS_DEV        - Skip prompt: 1=dev machine, 0=server
#   CHEZMOI_INSTALL_UI_APPS - Skip prompt: 1=install GUI apps, 0=skip
#   CHEZMOI_SHOULD_DECRYPT  - Skip prompt: 1=decrypt secrets, 0=skip

set -e

DOTFILES_REPO="tyvsmith/dotfiles"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; }

# Prompt for yes/no, returns 0 for yes, 1 for no
prompt_yn() {
    local prompt="$1"
    local default="${2:-n}"
    local reply

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    read -r -p "$prompt" reply
    reply="${reply:-$default}"

    [[ "$reply" =~ ^[Yy] ]]
}

echo ""
echo "╔════════════════════════════════════════╗"
echo "║        Ty's Dotfiles Installer         ║"
echo "╚════════════════════════════════════════╝"
echo ""

if [[ "$DOTFILES_BRANCH" != "main" ]]; then
    warn "Using branch: $DOTFILES_BRANCH"
fi

# =============================================================================
# Install system prerequisites
# =============================================================================
info "Checking prerequisites..."

if ! command -v git &> /dev/null || ! command -v gcc &> /dev/null; then
    info "Installing build tools..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! xcode-select -p &> /dev/null; then
            echo "Installing Xcode Command Line Tools..."
            xcode-select --install
            echo "Please wait for installation to complete, then re-run this script."
            exit 0
        fi
    elif command -v rpm-ostree &> /dev/null; then
        error "Missing build tools on rpm-ostree system (Fedora Silverblue/Bazzite/etc)"
        echo ""
        echo "Option 1 (Recommended): Use a distrobox container"
        echo "  distrobox enter <container-name>"
        echo "  # Then run this bootstrap script inside the container"
        echo ""
        echo "Option 2: Install to base system (requires reboot)"
        echo "  sudo rpm-ostree install gcc gcc-c++ make procps-ng curl file git"
        echo "  systemctl reboot"
        exit 1
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update
        sudo apt-get install -y build-essential procps curl file git
    elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y gcc gcc-c++ make procps-ng curl file git
    elif [[ -f /etc/arch-release ]] || command -v pacman &> /dev/null; then
        sudo pacman -Sy --needed --noconfirm base-devel procps-ng curl file git
    else
        error "Unsupported OS. Please install git, gcc, and build tools manually."
        exit 1
    fi
fi

# =============================================================================
# Install Homebrew
# =============================================================================
if ! command -v brew &> /dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Set up brew in PATH for this script
    if [[ "$OSTYPE" == "darwin"* ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# =============================================================================
# Install chezmoi
# =============================================================================
if ! command -v chezmoi &> /dev/null; then
    info "Installing chezmoi..."
    brew install chezmoi
fi

# =============================================================================
# Configuration prompts
# =============================================================================
info "Configuring dotfiles..."
echo ""

# --- is_dev ---
if [[ -z "${CHEZMOI_IS_DEV:-}" ]]; then
    echo "Machine type determines which packages are installed:"
    echo "  • Dev machine: SDKs, AI tools, dev utilities"
    echo "  • Server/minimal: Modern CLI tools only"
    echo ""
    if prompt_yn "Is this a development machine?" "y"; then
        export CHEZMOI_IS_DEV=1
    else
        export CHEZMOI_IS_DEV=0
    fi
    echo ""
fi

# --- install_ui_apps (macOS only) ---
if [[ "$OSTYPE" == "darwin"* ]] && [[ -z "${CHEZMOI_INSTALL_UI_APPS:-}" ]]; then
    if prompt_yn "Install GUI applications (IDEs, browsers, etc)?" "y"; then
        export CHEZMOI_INSTALL_UI_APPS=1
    else
        export CHEZMOI_INSTALL_UI_APPS=0
    fi
    echo ""
elif [[ "$OSTYPE" != "darwin"* ]]; then
    export CHEZMOI_INSTALL_UI_APPS=0
fi

# --- should_decrypt ---
if [[ -z "${CHEZMOI_SHOULD_DECRYPT:-}" ]]; then
    echo "Some configs (SSH trusted hosts) are encrypted with age."
    echo "Requires: 1Password CLI (op) or local key at ~/.config/chezmoi/age-key.txt"
    echo ""
    if prompt_yn "Enable decryption of private configs?" "n"; then
        export CHEZMOI_SHOULD_DECRYPT=1
    else
        export CHEZMOI_SHOULD_DECRYPT=0
    fi
    echo ""
fi

# =============================================================================
# Initialize chezmoi
# =============================================================================
info "Initializing chezmoi from $DOTFILES_REPO (branch: $DOTFILES_BRANCH)..."

chezmoi init --apply --branch="$DOTFILES_BRANCH" "$DOTFILES_REPO"

echo ""
success "Done! Restart your shell or run: exec fish"
