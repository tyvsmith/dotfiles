function tdl --description 'Tmux dev layout: editor + AI + terminal'
    if test (count $argv) -eq 0
        echo "Usage: tdl <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end

    if not set -q TMUX
        echo "You must start tmux to use tdl."
        return 1
    end

    set -l current_dir $PWD
    set -l ai $argv[1]
    set -l ai2 $argv[2]
    set -l editor_pane $TMUX_PANE

    # Name window after directory
    tmux rename-window -t $editor_pane (basename $current_dir)

    # Split: bottom 15% terminal
    tmux split-window -v -p 15 -t $editor_pane -c $current_dir

    # Split editor: right 30% for AI
    set -l ai_pane (tmux split-window -h -p 30 -t $editor_pane -c $current_dir -P -F '#{pane_id}')

    # Optional second AI below first
    if test -n "$ai2"
        set -l ai2_pane (tmux split-window -v -t $ai_pane -c $current_dir -P -F '#{pane_id}')
        tmux send-keys -t $ai2_pane $ai2 C-m
    end

    tmux send-keys -t $ai_pane $ai C-m
    tmux send-keys -t $editor_pane "$EDITOR ." C-m
    tmux select-pane -t $editor_pane
end
