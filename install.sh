#!/usr/bin/env bash
# Bootstrap script for new machines
#
# Usage:
#   Remote:  curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/install.sh | bash
#            curl ... | bash -s -- [options]
#   Local:   ./install.sh [options]
#
# Options:
#   --dev, --no-dev           Set machine type (default: prompt)
#   --work, --no-work         Work machine - uses system SSH agent (default: prompt)
#   --ui-apps, --no-ui-apps   Install GUI apps - macOS only (default: prompt on macOS)
#   --decrypt, --no-decrypt   Enable encrypted config decryption (default: no)
#   --branch <branch>         Git branch for remote install (default: main)
#   --defaults                Use default values, no prompts (dev=yes, ui-apps=yes, decrypt=no, work=no)
#   --quiet, -q               Minimal output
#   --help, -h                Show this help
#
# Environment variables (overridden by flags):
#   DOTFILES_BRANCH, DOTFILES_IS_DEV, DOTFILES_IS_WORK, DOTFILES_UI_APPS, DOTFILES_DECRYPT

set -e

# =============================================================================
# Configuration
# =============================================================================
DOTFILES_REPO="tyvsmith/dotfiles"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
LOCAL_SOURCE=""
QUIET=false
USE_DEFAULTS=false

# Config values (unset = prompt, 0 = no, 1 = yes)
OPT_IS_DEV="${DOTFILES_IS_DEV:-}"
OPT_IS_WORK="${DOTFILES_IS_WORK:-}"
OPT_UI_APPS="${DOTFILES_UI_APPS:-}"
OPT_DECRYPT="${DOTFILES_DECRYPT:-}"

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

show_help() {
    sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

# =============================================================================
# Parse arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev)        OPT_IS_DEV=1; shift ;;
        --no-dev)     OPT_IS_DEV=0; shift ;;
        --work)       OPT_IS_WORK=1; shift ;;
        --no-work)    OPT_IS_WORK=0; shift ;;
        --ui-apps)    OPT_UI_APPS=1; shift ;;
        --no-ui-apps) OPT_UI_APPS=0; shift ;;
        --decrypt)    OPT_DECRYPT=1; shift ;;
        --no-decrypt) OPT_DECRYPT=0; shift ;;
        --branch)     DOTFILES_BRANCH="$2"; shift 2 ;;
        --branch=*)   DOTFILES_BRANCH="${1#*=}"; shift ;;
        --defaults)   USE_DEFAULTS=true; shift ;;
        --quiet|-q)   QUIET=true; shift ;;
        --help|-h)    show_help ;;
        *)            error "Unknown option: $1"; show_help ;;
    esac
done

# Apply defaults if requested
if [[ "$USE_DEFAULTS" == true ]]; then
    OPT_IS_DEV="${OPT_IS_DEV:-1}"
    OPT_IS_WORK="${OPT_IS_WORK:-0}"
    OPT_UI_APPS="${OPT_UI_APPS:-1}"
    OPT_DECRYPT="${OPT_DECRYPT:-0}"
fi

# Detect local source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]]; then
    LOCAL_SOURCE="$SCRIPT_DIR"
fi

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
    info "Installing Homebrew Dependencies..."
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
# Install Homebrew
# =============================================================================
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# =============================================================================
# Install chezmoi
# =============================================================================
if ! command -v chezmoi &>/dev/null; then
    info "Installing chezmoi..."
    brew install chezmoi
fi

# =============================================================================
# Configuration
# =============================================================================
info "Configuring dotfiles..."

# --- is_dev ---
if [[ -z "$OPT_IS_DEV" ]]; then
    log ""
    log "Machine type determines which packages are installed:"
    log "  • Dev: SDKs, AI tools, dev utilities"
    log "  • Server: Modern CLI tools only"
    log ""
    if prompt_yn "Is this a development machine?" "y"; then
        OPT_IS_DEV=1
    else
        OPT_IS_DEV=0
    fi
fi
export DOTFILES_IS_DEV="$OPT_IS_DEV"

# --- is_work ---
if [[ -z "$OPT_IS_WORK" ]]; then
    log ""
    log "Work machines use the system SSH agent (for ussh compatibility)."
    log "Personal machines use 1Password SSH agent."
    log ""
    if prompt_yn "Is this a work/corporate machine?" "n"; then
        OPT_IS_WORK=1
    else
        OPT_IS_WORK=0
    fi
fi
export DOTFILES_IS_WORK="$OPT_IS_WORK"

# --- install_ui_apps (macOS only) ---
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -z "$OPT_UI_APPS" ]]; then
        log ""
        if prompt_yn "Install GUI applications (IDEs, browsers, etc)?" "y"; then
            OPT_UI_APPS=1
        else
            OPT_UI_APPS=0
        fi
    fi
else
    OPT_UI_APPS=0
fi
export DOTFILES_UI_APPS="$OPT_UI_APPS"

# --- should_decrypt ---
if [[ -z "$OPT_DECRYPT" ]]; then
    log ""
    log "Some configs (SSH trusted hosts) are encrypted with age."
    log "Requires: 1Password CLI or key at ~/.config/chezmoi/age-key.txt"
    log ""
    if prompt_yn "Enable decryption of private configs?" "n"; then
        OPT_DECRYPT=1
    else
        OPT_DECRYPT=0
    fi
fi
export DOTFILES_DECRYPT="$OPT_DECRYPT"

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
