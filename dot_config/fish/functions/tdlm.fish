function tdlm --description 'Tmux dev layout per subdirectory'
    if test (count $argv) -eq 0
        echo "Usage: tdlm <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end

    if not set -q TMUX
        echo "You must start tmux to use tdlm."
        return 1
    end

    set -l ai $argv[1]
    set -l ai2 $argv[2]
    set -l base_dir $PWD
    set -l first true

    # Rename session to current directory name
    tmux rename-session (basename $base_dir | tr '.:' '--')

    for dir in $base_dir/*/
        test -d $dir; or continue
        set -l dirpath (string replace -r '/$' '' $dir)

        if test $first = true
            tmux send-keys -t $TMUX_PANE "cd '$dirpath' && tdl $ai $ai2" C-m
            set first false
        else
            set -l pane_id (tmux new-window -c $dirpath -P -F '#{pane_id}')
            tmux send-keys -t $pane_id "tdl $ai $ai2" C-m
        end
    end
end
