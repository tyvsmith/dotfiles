#!/usr/bin/env bash
# Bootstrap script for new machines
#
# Usage:
#   Remote:  curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/install.sh | bash
#            curl ... | bash -s -- [options]
#   Local:   ./install.sh [options]
#
# Options:
#   --profile <name>          Machine profile (see profiles below)
#   --branch <branch>         Git branch for remote install (default: main)
#   --defaults                Use auto-detected profile, no prompts
#   --quiet, -q               Minimal output
#   --help, -h                Show this help
#
# Profiles:
#   macos-personal   Personal Mac — full dev setup with GUI apps
#   macos-work       Work Mac — full dev setup with corporate config
#   arch             Arch Linux desktop — full setup with paru + flatpak
#   debian-server    Debian/Ubuntu server — CLI tools only
#   debian-dev       Debian/Ubuntu dev — CLI + dev tools via apt
#   debian-brew      Debian/Ubuntu dev — Homebrew + flatpak
#   devpod           Work devpod — dev tools via Homebrew
#   fedora           Fedora Workstation — full setup with dnf + flatpak
#   silverblue       Silverblue/Bazzite — immutable desktop
#
# Environment variables (overridden by flags):
#   DOTFILES_BRANCH, DOTFILES_PROFILE

set -e

# =============================================================================
# Configuration
# =============================================================================
DOTFILES_REPO="tyvsmith/dotfiles"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
LOCAL_SOURCE=""
QUIET=false
USE_DEFAULTS=false
OPT_PROFILE="${DOTFILES_PROFILE:-}"

# =============================================================================
# Output helpers
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { [[ "$QUIET" == true ]] || echo -e "${BLUE}==>${NC} $1"; }
success() { [[ "$QUIET" == true ]] || echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}==>${NC} $1"; }
error()   { echo -e "${RED}==>${NC} $1" >&2; }
log()     { [[ "$QUIET" == true ]] || echo "$1"; }

show_help() {
    sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

# =============================================================================
# Parse arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)    OPT_PROFILE="$2"; shift 2 ;;
        --profile=*)  OPT_PROFILE="${1#*=}"; shift ;;
        --branch)     DOTFILES_BRANCH="$2"; shift 2 ;;
        --branch=*)   DOTFILES_BRANCH="${1#*=}"; shift ;;
        --defaults)   USE_DEFAULTS=true; shift ;;
        --quiet|-q)   QUIET=true; shift ;;
        --help|-h)    show_help ;;
        *)            error "Unknown option: $1"; show_help ;;
    esac
done

# Detect local source (skip when piped from curl — BASH_SOURCE[0] is empty)
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]]; then
        LOCAL_SOURCE="$SCRIPT_DIR"
    fi
fi

# =============================================================================
# Detect distro and default profile
# =============================================================================
detect_default_profile() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos-personal"
    elif [[ -e /run/ostree-booted ]]; then
        echo "silverblue"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/fedora-release ]]; then
        echo "fedora"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian-server"
    else
        echo "unknown"
    fi
}

DEFAULT_PROFILE="$(detect_default_profile)"

# =============================================================================
# Banner
# =============================================================================
if [[ "$QUIET" != true ]]; then
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║        Ty's Dotfiles Installer         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    if [[ -n "$LOCAL_SOURCE" ]]; then
        info "Using local source: $LOCAL_SOURCE"
    elif [[ "$DOTFILES_BRANCH" != "main" ]]; then
        warn "Using branch: $DOTFILES_BRANCH"
    fi
fi

# =============================================================================
# Install system prerequisites
# =============================================================================
info "Checking prerequisites..."

if ! command -v git &>/dev/null || ! command -v gcc &>/dev/null; then
    info "Installing build dependencies..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! xcode-select -p &>/dev/null; then
            xcode-select --install
            error "Please wait for Xcode Command Line Tools, then re-run."
            exit 0
        fi
    elif command -v rpm-ostree &>/dev/null; then
        error "Missing build tools on rpm-ostree system"
        log "  Option 1: distrobox enter <container>"
        log "  Option 2: sudo rpm-ostree install gcc gcc-c++ make procps-ng curl file git && reboot"
        exit 1
    elif [[ -f /etc/debian_version ]]; then
        sudo apt-get update && sudo apt-get install -y build-essential procps curl file git
    elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y gcc gcc-c++ make procps-ng curl file git
    elif [[ -f /etc/arch-release ]] || command -v pacman &>/dev/null; then
        sudo pacman -Sy --needed --noconfirm base-devel procps-ng curl file git
    else
        error "Unsupported OS. Install git, gcc, and build tools manually."
        exit 1
    fi
fi

# =============================================================================
# Install Homebrew (macOS only — Linux Homebrew handled by chezmoi scripts)
# =============================================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi
fi

# =============================================================================
# Install chezmoi
# =============================================================================
if ! command -v chezmoi &>/dev/null; then
    info "Installing chezmoi..."
    if command -v brew &>/dev/null; then
        brew install chezmoi
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm chezmoi
    else
        info "Using chezmoi install script..."
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# =============================================================================
# Profile selection
# =============================================================================
if [[ -z "$OPT_PROFILE" ]]; then
    if [[ "$USE_DEFAULTS" == true ]]; then
        OPT_PROFILE="$DEFAULT_PROFILE"
    else
        log ""
        log "Select a machine profile (defines packages, dev tools, GUI apps, etc.):"
        log ""
        log "  macos-personal   Personal Mac — full dev setup with GUI apps"
        log "  macos-work       Work Mac — full dev setup with corporate config"
        log "  arch             Arch Linux desktop — full setup with paru + flatpak"
        log "  debian-server    Debian/Ubuntu server — CLI tools only"
        log "  debian-dev       Debian/Ubuntu dev — CLI + dev tools via apt"
        log "  debian-brew      Debian/Ubuntu dev — Homebrew + flatpak"
        log "  devpod           Work devpod — dev tools via Homebrew"
        log "  fedora           Fedora Workstation — full setup with dnf + flatpak"
        log "  silverblue       Silverblue/Bazzite — immutable desktop"
        log ""
        read -r -p "Profile [$DEFAULT_PROFILE]: " OPT_PROFILE
        OPT_PROFILE="${OPT_PROFILE:-$DEFAULT_PROFILE}"
    fi
fi

export DOTFILES_PROFILE="$OPT_PROFILE"
info "Using profile: $OPT_PROFILE"

# =============================================================================
# Initialize chezmoi
# =============================================================================
if [[ -n "$LOCAL_SOURCE" ]]; then
    info "Applying dotfiles from local source..."
    chezmoi init --apply --source="$LOCAL_SOURCE"
else
    info "Applying dotfiles from $DOTFILES_REPO..."
    chezmoi init --apply --branch="$DOTFILES_BRANCH" "$DOTFILES_REPO"
fi

success "Done! Restart your shell or run: exec fish"
