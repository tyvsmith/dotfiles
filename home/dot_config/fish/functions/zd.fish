function zd --description 'cd, falling through to zoxide when the target is not a directory'
    # __zd_cd is a copy of fish's own cd (keeps dirprev/dirnext and `cd -`),
    # made in zz_03_interactive.fish before cd is wrapped to call this.
    if not functions -q __zd_cd
        builtin cd $argv
        return
    end

    if test (count $argv) -eq 0
        __zd_cd ~
    else if test -d $argv[1]; or string match -q -- '-*' $argv[1]
        __zd_cd $argv
    else
        if not z $argv
            echo "Error: Directory not found"
            return 1
        end
        printf '\U000F17A9 '
        pwd
    end
end
