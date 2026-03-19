function __cached_source --description 'Source a command output with stale-while-revalidate caching'
    # Usage: __cached_source <tool_or_path> <subcommands...>
    # Example: __cached_source zoxide init fish
    # Example: __cached_source /home/linuxbrew/.linuxbrew/bin/brew shellenv
    #
    # Caches output to ~/.cache/fish/<name>.fish
    # On cache hit: sources immediately (zero validation cost — all builtins)
    # If tool binary is newer than cache: regenerates in background for next startup
    # Accepts full paths — uses basename for the cache filename.

    set -l tool $argv[1]
    set -l subcmd $argv[2..-1]
    set -l name (string replace -r '.*/' '' $tool)

    set -l tool_path (command -s $tool 2>/dev/null)
    if test -z "$tool_path"
        # Tool not installed — skip silently
        return 1
    end

    set -l cache_dir ~/.cache/fish
    set -l cache_file $cache_dir/$name.fish

    if test -s "$cache_file"
        source $cache_file
        # Stale-while-revalidate: if tool binary was updated, regenerate for next startup
        if test "$tool_path" -nt "$cache_file"
            $tool $subcmd >$cache_file &
            disown 2>/dev/null
        end
    else
        # Cold start: generate synchronously
        mkdir -p $cache_dir
        # Clean up old versioned cache files (previous naming scheme)
        for old in $cache_dir/$name.*.fish
            command rm -f $old
        end
        $tool $subcmd >$cache_file
        if test -s "$cache_file"
            source $cache_file
        else
            command rm -f $cache_file
            return 0
        end
    end
end
