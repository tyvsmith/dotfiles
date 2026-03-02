# =============================================================================
# Atuin — shell history search
# Replaces default bash Ctrl+R with atuin's fuzzy search
# Omarchy uses standard bash history; this upgrades to atuin
# =============================================================================

if command -v atuin &>/dev/null; then
  eval "$(atuin init bash)"
fi
