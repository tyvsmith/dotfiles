# =============================================================================
# Atuin — shell history search
# Replaces default bash Ctrl+R with atuin's fuzzy search
# Omarchy uses standard bash history; this upgrades to atuin
# =============================================================================

if command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"

  # ble.sh's ble-bind takes priority over readline's bind. Since fzf
  # integration (03-fzf.bash) binds C-r to fzf-history-widget via ble-bind,
  # and atuin uses readline bind, we need to override at the ble-bind level
  # so atuin's history search wins.
  if [[ ${BLE_VERSION-} ]]; then
    ble-bind -m emacs -x C-r '__atuin_history --keymap-mode=emacs'
  fi
fi
