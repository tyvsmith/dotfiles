function eff --description 'fzf file picker → open in $EDITOR'
    set -l file (fzf --preview 'bat --style=numbers --color=always {}')
    and $EDITOR $file
end
