function __fzf_cd --description 'Pick a directory with fzf and cd into it (bash fzf Alt+C)'
    set -l dir (fd --type d --hidden --follow --exclude .git 2>/dev/null |
        fzf --preview 'eza --tree --level=2 --icons=auto --color=always {}' $fzf_directory_opts)
    and cd $dir
    commandline -f repaint
end
