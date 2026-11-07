function ff --description 'fzf file picker with bat preview (kitty gets image preview)'
    set -l preview 'bat --style=numbers --color=always {}'
    if test "$TERM" = xterm-kitty
        set preview 'case $(file --mime-type -b {}) in image/*) kitty icat --clear --transfer-mode=memory --stdin=no --place=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0 {} ;; *) bat --style=numbers --color=always {} ;; esac'
    end
    fzf --preview $preview $argv
end
