#!/usr/bin/env bash

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 not found"
}

require_file() {
  [[ -f "$1" ]] || fail "File $1 not found"
}

# Render a chezmoi template from the source directory
render_template() {
  local src_dir="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}"
  chezmoi execute-template < "$src_dir/$1"
}

ensure_brew_in_path() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi
}

# Install a package using whatever package manager is available.
# Usage: ensure_pkg <command_name> [package_name]
# If package_name is omitted, command_name is used as the package name.
ensure_pkg() {
  local cmd="$1"
  local pkg="${2:-$1}"
  command -v "$cmd" &>/dev/null && return 0

  log "Installing $pkg..."
  if command -v paru &>/dev/null; then
    paru -S --needed --noconfirm "$pkg"
  elif command -v yay &>/dev/null; then
    yay -S --needed --noconfirm "$pkg"
  elif command -v pacman &>/dev/null; then
    # Try official repos first, fall back to building from AUR
    if ! sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
      log "$pkg not in official repos, building from AUR..."
      sudo pacman -S --needed --noconfirm base-devel git
      local aur_tmp="$(mktemp -d)"
      git clone "https://aur.archlinux.org/${pkg}.git" "$aur_tmp/$pkg"
      (cd "$aur_tmp/$pkg" && makepkg -si --noconfirm)
      rm -rf "$aur_tmp"
    fi
  elif ensure_brew_in_path && command -v brew &>/dev/null; then
    brew install "$pkg"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y "$pkg"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$pkg"
  else
    fail "Cannot install $pkg: no supported package manager found"
  fi
}
