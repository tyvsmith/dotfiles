function __cached_source --description 'Source a command output with version-based caching'
    # Usage: __cached_source <tool_or_path> <subcommands...>
    # Example: __cached_source zoxide init fish
    # Example: __cached_source /home/linuxbrew/.linuxbrew/bin/brew shellenv
    #
    # Runs `<tool> <subcommands>`, caches output to ~/.cache/fish/<name>.<version>.fish
    # Invalidates when `<tool> --version` output changes.
    # Accepts full paths — uses basename for the cache filename.

    set -l tool $argv[1]
    set -l subcmd $argv[2..-1]
    set -l name (string replace -r '.*/' '' $tool)

    set -l cache_dir ~/.cache/fish
    set -l ver ($tool --version 2>/dev/null | string trim)

    if test -z "$ver"
        # Tool not installed — skip silently
        return 1
    end

    set -l cache_file $cache_dir/$name.$ver.fish

    if not test -f $cache_file
        mkdir -p $cache_dir
        for old in $cache_dir/$name.*.fish
            command rm -f $old
        end
        $tool $subcmd >$cache_file
    end

    source $cache_file
end
