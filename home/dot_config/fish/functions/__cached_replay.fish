function __cached_replay --description 'Replay a bash script with mtime-based caching'
    # Usage: __cached_replay <name> <bash_source_command>
    # Example: __cached_replay cpe "source /etc/zsh/cpe 2>/dev/null"
    #
    # On cache hit: sources cache directly — no subprocess at all.
    # Invalidates when the source file's mtime changes (test -nt, builtin).
    # On cache miss: runs replay in a clean fish subprocess, captures the
    # resulting set -gx / fish_add_path commands.

    set -l name $argv[1]
    set -l cmd $argv[2]

    set -l src_file (string match -r 'source\s+(\S+)' -- $cmd)[2]
    set src_file (string replace '~' $HOME -- $src_file)

    if not test -f "$src_file"
        return 1
    end

    set -l cache_dir ~/.cache/fish
    set -l cache_file $cache_dir/$name.fish

    # Cache hit: file exists and source hasn't changed (all builtins, zero cost)
    if test -s "$cache_file" -a ! "$src_file" -nt "$cache_file"
        source $cache_file
        return 0
    end

    # Cache miss or stale: regenerate synchronously
    mkdir -p $cache_dir
    # Clean up old versioned cache files (previous naming scheme)
    for old in $cache_dir/$name.*.fish
        command rm -f $old
    end

    # Run replay in a clean fish subprocess with minimal env.
    # Emit set -gx for every exported var that replay introduced.
    set -l fish_bin (command -s fish)
    env -i HOME=$HOME USER=$USER $fish_bin --no-config -c '
        source '$HOME'/.config/fish/functions/replay.fish
        replay "'$cmd'"
        for v in (set --export --names)
            contains -- $v SHLVL _ PWD HOME USER; and continue
            if test "$v" = PATH
                for p in $PATH
                    contains -- $p /usr/bin /bin /usr/sbin /sbin; or echo "fish_add_path --path "(string escape -- $p)
                end
            else
                echo "set -gx $v "(string join " " -- (string escape -- $$v))
            end
        end
    ' >$cache_file

    if test -s "$cache_file"
        source $cache_file
    else
        command rm -f $cache_file
        return 0
    end
end
