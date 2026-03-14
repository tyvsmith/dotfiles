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

    # Reset cursor to bar on each prompt. Tmux doesn't restore cursor shape
    # after apps (neovim, opencode, etc.) change it, unlike Ghostty natively.
    # Only needed inside tmux — Ghostty handles this via alt-screen restore.
    if set -q TMUX
        function __reset_cursor --on-event fish_prompt
            printf '\e[6 q'
        end

        # Refresh SSH_AUTH_SOCK from tmux session environment on each prompt.
        # tmux update-environment only sets vars on attach/new-session, so
        # existing shells can have stale values (breaks ussh, git over ssh, etc.)
        function __refresh_ssh_auth_sock --on-event fish_prompt
            set -l val (tmux show-environment SSH_AUTH_SOCK 2>/dev/null)
            if string match -q 'SSH_AUTH_SOCK=*' $val
                set -gx SSH_AUTH_SOCK (string replace 'SSH_AUTH_SOCK=' '' $val)
            end
        end
    end

end