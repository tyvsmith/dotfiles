status is-interactive; or return

function t --wraps tmux --description 'Attach to tmux; create Work when no arguments are given'
    if set -q argv[1]
        tmux attach $argv
    else
        tmux attach; or tmux new -s Work
    end
end
