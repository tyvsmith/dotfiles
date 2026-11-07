function tds --description 'Tmux dev square: editor, diff watch, terminal, opencode'
    if test (count $argv) -ne 0
        echo "Usage: tds"
        return 1
    end

    if not set -q TMUX
        echo "You must start tmux to use tds."
        return 1
    end

    set -l current_dir $PWD
    set -l editor_pane $TMUX_PANE

    tmux rename-window -t $editor_pane (basename $current_dir)

    set -l terminal_pane (tmux split-window -v -p 50 -t $editor_pane -c $current_dir -P -F '#{pane_id}')
    set -l diff_pane (tmux split-window -h -p 50 -t $editor_pane -c $current_dir -P -F '#{pane_id}')
    set -l opencode_pane (tmux split-window -h -p 50 -t $terminal_pane -c $current_dir -P -F '#{pane_id}')

    tmux send-keys -t $editor_pane -l "nvim ."
    tmux send-keys -t $editor_pane C-m
    tmux send-keys -t $diff_pane -l "hunk diff --watch"
    tmux send-keys -t $diff_pane C-m
    tmux send-keys -t $opencode_pane -l opencode
    tmux send-keys -t $opencode_pane C-m

    tmux select-pane -t $editor_pane
end
