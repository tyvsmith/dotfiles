complete -c opencode -f

function __opencode_yargs_completions --description 'OpenCode yargs completions with context cache'
    set -l tool_path (command -s opencode 2>/dev/null)
    if test -z "$tool_path"
        return 1
    end

    set -l tokens (commandline -opc)
    set -l cur (commandline -ct)
    if test -n "$cur"
        set tokens $tokens $cur
    end

    set -l cache_dir ~/.cache/fish/opencode-completions
    mkdir -p $cache_dir

    set -l key
    if test (count $tokens) -eq 0
        set key __root__
    else
        set -l raw_key (string join \x1f -- $tokens)
        set key (string replace -ra '[^A-Za-z0-9._-]' '_' -- $raw_key)
        if test -z "$key"
            set key __empty__
        end
    end

    set -l cache_file $cache_dir/$key.txt
    set -l tmp_file $cache_file.tmp

    if test -s "$cache_file"
        command cat $cache_file
        if test "$tool_path" -nt "$cache_file"
            begin
                opencode --get-yargs-completions $tokens >$tmp_file 2>/dev/null
                and command mv $tmp_file $cache_file
                or command rm -f $tmp_file
            end &
            disown 2>/dev/null
        end
        return 0
    end

    opencode --get-yargs-completions $tokens >$tmp_file 2>/dev/null
    if test -s "$tmp_file"
        command mv $tmp_file $cache_file
        command cat $cache_file
    else
        command rm -f $tmp_file
    end
end

complete -c opencode -f -k -a '(__opencode_yargs_completions)'
complete -c opencode --force-files
