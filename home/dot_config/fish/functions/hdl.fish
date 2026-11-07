function hdl --description 'Herdr dev layout: editor + AI + terminal'
    if test (count $argv) -eq 0
        echo "Usage: hdl <c|cx|codex|other_ai> [<second_ai>]"
        return 1
    end

    if not set -q HERDR_PANE_ID
        echo "You must start herdr to use hdl."
        return 1
    end

    set -l current_dir $PWD
    set -l ai $argv[1]
    set -l ai2 $argv[2]

    # HERDR_PANE_ID is the pane we're running in (stable even if focus moves)
    set -l editor_pane $HERDR_PANE_ID

    # Name the current tab after the base directory name
    herdr tab rename $HERDR_TAB_ID (basename $current_dir) >/dev/null

    # Split tab vertically - top 85%, bottom 15%
    __herdr_split $editor_pane down 0.85 $current_dir >/dev/null

    # Split editor pane horizontally - AI on right 30%
    set -l ai_pane (__herdr_split $editor_pane right 0.7 $current_dir)

    # Optional second AI below the first
    if test -n "$ai2"
        set -l ai2_pane (__herdr_split $ai_pane down 0.5 $current_dir)
        herdr pane run $ai2_pane $ai2 >/dev/null
    end

    herdr pane run $ai_pane $ai >/dev/null
    herdr pane run $editor_pane "$EDITOR ." >/dev/null
end
