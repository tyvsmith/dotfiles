# =============================================================================
# Abbreviations (ble.sh sabbrev + alias)
# Mirrors fish's abbreviations — type keyword, hit Space/Enter, it expands.
# Each entry is both an alias (so ble.sh highlights it as valid) and a sabbrev
# (so it expands visibly). Without ble.sh, plain aliases are used.
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

# Helper: alias + dynamic sabbrev that only expands in command position.
# Used for tool replacements where the name clashes with subcommands
# (e.g. "git diff" must not become "git difft").
_abbr_cmd() {
  local name="$1" expansion="$2"
  alias "$name=$expansion"
  [[ ${BLE_VERSION-} ]] && ble-sabbrev -m "$name=_ble_abbr_cmd_expand ${name} ${expansion}"
}

# Helper: alias + sabbrev (expands visibly anywhere — use for unique shorthand only)
_abbr() {
  local name="$1" expansion="$2"
  alias "$name=$expansion"
  [[ ${BLE_VERSION-} ]] && ble-sabbrev "$name=$expansion"
}

# --- Modern CLI tool replacements (command-position only) ---
# These override real commands and must NOT expand when used as subcommands
# (e.g. "git diff", "git grep", "docker rm")
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
_abbr_cmd grep  'rg'
_abbr_cmd find  'fd'
_abbr_cmd sed   'sd'
_abbr_cmd curl  'xh'
_abbr_cmd vim   'nvim'
_abbr_cmd vi    'nvim'

# --- Shorthand (safe to expand anywhere — unique words) ---
_abbr lg    'lazygit'
_abbr br    'broot'
_abbr cz    'chezmoi'

# --- AI tools ---
_abbr c     'opencode'
_abbr cx    'printf "\033[2J\033[3J\033[H" && claude --allow-dangerously-skip-permissions'

# --- Common tools ---
_abbr d     'docker'
_abbr p     'podman'
_abbr t     'tmux attach || tmux new -s Work'

# --- Git ---
_abbr g     'git'
_abbr gcm   'git commit -m'
_abbr gcam  'git commit -a -m'
_abbr gcad  'git commit -a --amend'

# --- Directory navigation ---
_abbr ..    'cd ..'
_abbr ...   'cd ../..'
_abbr ....  'cd ../../..'

# --- Container management ---
_abbr db    'distrobox'
_abbr dbe   'distrobox enter'
_abbr dbl   'distrobox list'
_abbr dbs   'distrobox stop'
_abbr dbrm  'distrobox rm'
_abbr dbc   'distrobox create'

# --- Zellij ---
_abbr zj    'zellij'

unset -f _abbr _abbr_cmd
