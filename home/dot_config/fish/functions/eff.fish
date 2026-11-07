function eff --description 'fzf file picker → open in $EDITOR'
    set -l file (ff)
    and $EDITOR $file
end
