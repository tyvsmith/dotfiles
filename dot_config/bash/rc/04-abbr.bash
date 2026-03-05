# =============================================================================
# Abbreviations (ble.sh sabbrev + alias)
# Mirrors fish's abbreviations — type keyword, hit Space/Enter, it expands.
# All abbreviations are command-position-only (like fish's default), so
# "paru -S d" won't expand "d" to "docker".
# Each entry is both an alias (so ble.sh highlights it as valid) and a
# dynamic sabbrev (so it expands visibly). Without ble.sh, plain aliases work.
# =============================================================================

# ---------------------------------------------------------------------------
# Command-position check for ble.sh dynamic sabbrev (-m)
# Emulates fish's `abbr --position command` — only expands when the word is
# the command (first token, or after |, &&, ||, ;, (, {, $(), `).
# ---------------------------------------------------------------------------
_ble_abbr_cmd_expand() {
  local name="$1"; shift
  local expansion="$*"
  local prefix="${_ble_edit_str::_ble_edit_ind}"
  prefix="${prefix%"$name"}"
  # Command position: start of line / after shell operators / newline
  if [[ "$prefix" =~ ^[[:space:]]*$ || "$prefix" =~ [$';\n|&(){}'\`][[:space:]]*$ ]]; then
    COMPREPLY=("$expansion")
  fi
}

# Register alias + dynamic sabbrev (command-position-only expansion).
_abbr_cmd() {
  local name="$1" expansion="$2"
  alias "$name=$expansion"
  [[ ${BLE_VERSION-} ]] && ble-sabbrev -m "$name=_ble_abbr_cmd_expand ${name} ${expansion}"
}

# --- Modern CLI tool replacements ---
_abbr_cmd ls    'eza'
_abbr_cmd ll    'eza -l --icons=auto --group-directories-first'
_abbr_cmd la    'eza -la --icons=auto --group-directories-first'
_abbr_cmd lt    'eza --tree --level=2'
_abbr_cmd l.    'eza -d .*'
_abbr_cmd l1    'eza -1'
_abbr_cmd cat   'bat'
_abbr_cmd rm    'trash'
_abbr_cmd diff  'difft'
_abbr_cmd df    'duf'
_abbr_cmd du    'dust'
_abbr_cmd ping  'gping'
#_abbr_cmd grep  'rg'
_abbr_cmd find  'fd'
_abbr_cmd sed   'sd'
_abbr_cmd curl  'xh'
_abbr_cmd vim   'nvim'
_abbr_cmd vi    'nvim'

# --- Shorthand for modern tools ---
_abbr_cmd lg    'lazygit'
_abbr_cmd br    'broot'
_abbr_cmd cz    'chezmoi'

# --- AI tools ---
_abbr_cmd c     'opencode'
_abbr_cmd cx    'printf "\033[2J\033[3J\033[H" && claude --allow-dangerously-skip-permissions'

# --- Common tools ---
_abbr_cmd d     'docker'
_abbr_cmd p     'podman'
_abbr_cmd t     'tmux attach || tmux new -s Work'

# --- Git ---
_abbr_cmd g     'git'
_abbr_cmd gcm   'git commit -m'
_abbr_cmd gcam  'git commit -a -m'
_abbr_cmd gcad  'git commit -a --amend'

# --- Directory navigation ---
_abbr_cmd ..    'cd ..'
_abbr_cmd ...   'cd ../..'
_abbr_cmd ....  'cd ../../..'

# --- Container management ---
_abbr_cmd db    'distrobox'
_abbr_cmd dbe   'distrobox enter'
_abbr_cmd dbl   'distrobox list'
_abbr_cmd dbs   'distrobox stop'
_abbr_cmd dbrm  'distrobox rm'
_abbr_cmd dbc   'distrobox create'

# --- Zellij ---
_abbr_cmd zj    'zellij'

unset -f _abbr_cmd
