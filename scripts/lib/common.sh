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

ensure_brew_in_path() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      # Install Homebrew on macOS if not found
      log "Homebrew not found, installing..."
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Now set up the path
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
  else
    if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
      eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    else
      # Install Homebrew on Linux if not found
      log "Homebrew not found, installing..."

      # Install prerequisites via system package manager
      if command -v apt-get &>/dev/null; then
        log "Installing Homebrew prerequisites via apt..."
        sudo apt-get update
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
          build-essential curl file git procps
      elif command -v dnf &>/dev/null; then
        log "Installing Homebrew prerequisites via dnf..."
        sudo dnf install -y gcc make curl file git procps-ng
      fi

      log "Installing Homebrew..."
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Now set up the path
      if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
      fi
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

# Install the candidates a probe command reports available; warn about the rest.
# Usage: install_probed <probe-cmd> <install-cmd> <unavailable-msg> [hint...]
# Reads CANDIDATE_PACKAGES (declare -A, pkg_name -> display_name) from the caller:
# bash cannot pass associative arrays. Commands are split on whitespace and
# run as "<probe-cmd> <pkg>" and "<install-cmd> <pkg>...".
install_probed() {
  local unavailable_msg="$3" pkg_name pkg hint
  local -a probe install available=() missing=() hints
  read -ra probe <<<"$1"
  read -ra install <<<"$2"
  shift 3
  hints=("$@")

  for pkg_name in "${!CANDIDATE_PACKAGES[@]}"; do
    if "${probe[@]}" "$pkg_name" &>/dev/null; then
      available+=("$pkg_name")
    else
      missing+=("${CANDIDATE_PACKAGES[$pkg_name]}")
    fi
  done
  # Sort for deterministic output
  if [[ ${#available[@]} -gt 0 ]]; then
    mapfile -t available < <(printf '%s\n' "${available[@]}" | sort)
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort)
  fi

  log "Installing ${#available[@]} packages..."
  if [[ ${#available[@]} -gt 0 ]]; then
    "${install[@]}" "${available[@]}"
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "$unavailable_msg"
    for pkg in "${missing[@]}"; do
      warn "  - $pkg"
    done
    if [[ ${#hints[@]} -gt 0 ]]; then
      log ""
      log "To install missing tools, consider:"
      local i=1
      for hint in "${hints[@]}"; do
        log "  $i. $hint"
        i=$((i + 1))
      done
    fi
  fi
}
