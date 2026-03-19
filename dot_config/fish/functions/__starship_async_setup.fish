# Ensure starship functions are saved to disk for fish-async-prompt's background
# fish process, and generate a sync config (no git_status) for the loading indicator.
# Only re-runs when starship binary or config changes (mtime checks).
function __starship_async_setup
    __cached_source starship init fish --print-full-init

    set -l starship_bin (command -s starship)
    test -n "$starship_bin"; or return

    # Save starship functions to disk so background fish -c can autoload them
    set -l saved ~/.config/fish/functions/fish_prompt.fish
    if test ! -e "$saved" -o "$starship_bin" -nt "$saved"
        for func in fish_prompt fish_right_prompt __starship_set_job_count
            functions -q $func; and funcsave $func >/dev/null 2>&1
        end
    end

    # Generate sync config (strip $git_status) for loading indicator
    set -l conf ~/.config/starship.toml
    set -l sync ~/.cache/fish/starship-sync.toml
    if test -e "$conf" -a \( ! -e "$sync" -o "$conf" -nt "$sync" \)
        command sed 's/\$git_status//' "$conf" >"$sync"
    end
    set -g __fish_prompt_last_dir $PWD
end
