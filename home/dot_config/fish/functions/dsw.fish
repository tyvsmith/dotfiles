function dsw --description 'Stop all rsync-on-change watchers'
    set -l found 0
    for pid in (pgrep -f 'rsw-watch ')
        kill -- -$pid 2>/dev/null
        and echo "Stopped watch (pid $pid)"
        and set found 1
    end
    test $found -eq 1; or echo "No active watches"
end
