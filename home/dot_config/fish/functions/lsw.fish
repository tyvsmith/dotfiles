function lsw --description 'List active rsync-on-change watchers'
    set -l found 0
    for line in (pgrep -af 'rsw-watch ')
        set -l pid (string split -m1 ' ' -- $line)[1]
        set -l parts (string replace -r '.*rsw-watch ' '' -- $line | string split ' ')
        echo "$pid: $parts[1..-2] -> $parts[-1]"
        set found 1
    end
    test $found -eq 1; or echo "No active watches"
end
