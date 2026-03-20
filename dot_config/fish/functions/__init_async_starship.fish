# Starship async prompt setup
# 1. Init starship synchronously (fish_prompt must exist before fish-async-prompt wraps it)
# 2. Background: save functions to disk for fish-async-prompt's background fish process,
#    and generate sync config (no git_status) for loading indicator.
function __init_async_starship
    # Synchronous — must complete before fish-async-prompt's first fish_prompt event
    __cached_source starship init fish --print-full-init
    set -g __fish_prompt_last_dir $PWD

    # Background — only needed for subsequent prompts / next shell session
    fish -c '
        set -l starship_bin (command -s starship)
        test -n "$starship_bin"; or exit

        # Save starship functions so background fish -c can autoload them
        set -l saved ~/.config/fish/functions/fish_prompt.fish
        if test ! -e "$saved" -o "$starship_bin" -nt "$saved"
            source ~/.cache/fish/starship.fish
            for func in fish_prompt fish_right_prompt __starship_set_job_count
                functions -q $func; and funcsave $func >/dev/null 2>&1
            end
        end

        # Generate sync config (strip $git_status) for loading indicator
        set -l conf ~/.config/starship.toml
        set -l sync ~/.cache/fish/starship-sync.toml
        if test -e "$conf" -a \( ! -e "$sync" -o "$conf" -nt "$sync" \)
            string replace -a "\$git_status" "" <"$conf" >"$sync"
        end
    ' &
    disown 2>/dev/null
end
