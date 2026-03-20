# Loading indicator for fish-async-prompt
# Same directory: reuse previous prompt (keeps cached git status, no visual jump)
# New directory: render starship without git_status for instant display
function fish_prompt_loading_indicator
    if test "$PWD" = "$__fish_prompt_last_dir"
        echo -n $argv[1]
    else
        STARSHIP_CONFIG=~/.cache/fish/starship-sync.toml command starship prompt --terminal-width="$COLUMNS" --status=0 --cmd-duration=0 --jobs=0
    end
    set -g __fish_prompt_last_dir $PWD
end
