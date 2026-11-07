# =============================================================================
# REMOVED - Learn the new syntax directly:
# - grep → use 'rg' (different: rg "pattern" vs grep -r "pattern" .)
# - find → use 'fd' (different: fd "pattern" vs find . -name "pattern")
# - du   → use 'dust' (just run it, no args needed)
# - df   → use 'duf' (just run it, no args needed)
# - ps   → use 'procs' (just run it, no args needed)
# - sed  → use 'sd' (different: sd 'old' 'new' file)
# - curl → use 'xh' (different: xh GET url)
# =============================================================================

# Random modern CLI tips - shows 2 random tips each shell.
# The tip list is shared with bash: ~/.config/shell/cli-tips.txt
function fish_greeting
    set -l tips_file ~/.config/shell/cli-tips.txt
    test -r $tips_file; or return 0

    # Only show tips once every 6 hours
    set -l stamp_file ~/.cache/fish_greeting_stamp
    set -l interval 21600 # 6 hours in seconds
    set -l now (date +%s)
    set -l show false

    if not test -f $stamp_file
        set show true
    else
        set -l last (cat $stamp_file)
        if test (math $now - $last) -ge $interval
            set show true
        end
    end

    if test $show = false
        return
    end

    mkdir -p ~/.cache
    echo $now > $stamp_file

    set -l tips (string match -rv '^\s*(#|$)' < $tips_file)
    set -l count (count $tips)
    test $count -ge 2; or return 0
    set -l idx1 (random 1 $count)
    set -l idx2 (random 1 $count)

    # Ensure we get two different tips
    while test $idx1 -eq $idx2
        set idx2 (random 1 $count)
    end

    set_color cyan
    echo "💡 Modern CLI tips:"
    set_color normal
    echo "  $tips[$idx1]"
    echo "  $tips[$idx2]"
end
