function __hybrid_zoxide_z_complete
    set -l tokens (commandline --current-process --tokenize)
    set -l curr_tokens (commandline --cut-at-cursor --current-process --tokenize)

    if test (count $tokens) -le 2 -a (count $curr_tokens) -eq 1
        set -l query $tokens[2..-1]
        zoxide query --exclude (__zoxide_pwd) --list -- $query
    else
        __zoxide_z_complete
    end
end