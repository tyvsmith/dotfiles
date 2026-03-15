#!/usr/bin/env bash
# Bootstrap dotfiles on a new machine
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/install.sh | bash
#   curl ... | bash -s -- --profile macos-work
#   curl ... | bash -s -- --profile debian-server --branch feature-x
#
# Options:
#   --profile <name>      Machine profile (skips interactive prompt)
#   --branch <branch>     Git branch (default: main)
#   --age-key <key>       Age secret key content (written to ~/.config/chezmoi/age-key.txt)
#   --help, -h            Show this help

set -e

DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
OPT_PROFILE="${DOTFILES_PROFILE:-}"
AGE_KEY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)    OPT_PROFILE="$2"; shift 2 ;;
        --profile=*)  OPT_PROFILE="${1#*=}"; shift ;;
        --branch)     DOTFILES_BRANCH="$2"; shift 2 ;;
        --branch=*)   DOTFILES_BRANCH="${1#*=}"; shift ;;
        --age-key)    AGE_KEY="$2"; shift 2 ;;
        --age-key=*)  AGE_KEY="${1#*=}"; shift ;;
        --help|-h)    sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# \?//'; exit 0 ;;
        *)            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ -n "$OPT_PROFILE" ]] && export DOTFILES_PROFILE="$OPT_PROFILE"
[[ -n "$AGE_KEY" ]] && export DOTFILES_AGE_KEY="$AGE_KEY"

INIT_ARGS=(init --apply tyvsmith)
[[ "$DOTFILES_BRANCH" != "main" ]] && INIT_ARGS+=(--branch "$DOTFILES_BRANCH")

# Install chezmoi to ~/.local/bin, then init + apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- "${INIT_ARGS[@]}"

echo "Done! Restart your shell or run: exec fish"
