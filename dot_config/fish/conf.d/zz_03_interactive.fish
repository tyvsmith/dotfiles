# =============================================================================
# Interactive Shell Setup
# Tool initialization that must run in every interactive session
# (zoxide, atuin, fzf overrides, prompt variables)
# Runs after all plugins (zz_ prefix) so keybindings stick
# Cached via __cached_source — regenerated when tool versions change
# =============================================================================

if status is-interactive
    # fzf.fish — disable history binding (atuin owns Ctrl+R)
    fzf_configure_bindings --history=

    # Atuin — shell history search (binds Ctrl+R and Up)
    __cached_source atuin init fish
    
    # Zoxide — smart directory jumping
    __cached_source zoxide init fish

    complete --erase --command __zoxide_z
    complete --command __zoxide_z --no-files --arguments '(__hybrid_zoxide_z_complete)'

    # Set simple hostname for prompt display
    set -gx HOST (string split -f1 '.' $hostname)
end