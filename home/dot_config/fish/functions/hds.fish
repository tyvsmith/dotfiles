function hds --description 'Herdr dev square: editor, diff watch, terminal, opencode'
    if test (count $argv) -ne 0
        echo "Usage: hds"
        return 1
    end

    if not set -q HERDR_PANE_ID
        echo "You must start herdr to use hds."
        return 1
    end

    set -l current_dir $PWD
    set -l editor_pane $HERDR_PANE_ID

    herdr tab rename $HERDR_TAB_ID (basename $current_dir) >/dev/null

    set -l terminal_pane (__herdr_split $editor_pane down 0.5 $current_dir)
    set -l diff_pane (__herdr_split $editor_pane right 0.5 $current_dir)
    set -l opencode_pane (__herdr_split $terminal_pane right 0.5 $current_dir)

    herdr pane run $editor_pane "nvim ." >/dev/null
    herdr pane run $diff_pane "hunk diff --watch" >/dev/null
    herdr pane run $opencode_pane opencode >/dev/null
end
