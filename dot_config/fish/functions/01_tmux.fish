function tmux --wraps tmux --description 'tmux with session restore'
    if test (count $argv) -eq 0
        # Bare "tmux": restore previous sessions if available, then attach
        if not command tmux has-session 2>/dev/null
            # No server running - start detached, restore, then attach
            command tmux new-session -d; or return $status
            if test -f ~/.local/share/tmux/resurrect/last
                command tmux run-shell ~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh
            end
            command tmux attach
        else
            command tmux attach
        end
    else
        command tmux $argv
    end
end
