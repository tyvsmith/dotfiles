# =============================================================================
# Personal Bash Extensions
# Adds features on top of omarchy's default bash config.
# Source this from ~/.bashrc AFTER the omarchy `source ... /default/bash/rc` line:
#
#   source ~/.config/bash/init.bash
#
# Provides: ble.sh (syntax highlighting + autosuggestions + abbreviations),
# atuin (shell history), tmux cursor reset, CLI tips greeting.
# =============================================================================

[[ $- != *i* ]] && return

# ble.sh must be loaded early with --noattach, then attached at the end.
# Everything between runs in "vanilla" bash so omarchy's config isn't affected.
# Check system install (pacman) first, then user install (curl/make).
if [[ -f /usr/share/blesh/ble.sh ]]; then
  source /usr/share/blesh/ble.sh --noattach
elif [[ -f ~/.local/share/blesh/ble.sh ]]; then
  source ~/.local/share/blesh/ble.sh --noattach
fi

# Source all rc/*.bash files in order
for f in ~/.config/bash/rc/*.bash; do
  [[ -f "$f" ]] && source "$f"
done

# Attach ble.sh (must be last — takes over line editing)
[[ ${BLE_VERSION-} ]] && ble-attach
