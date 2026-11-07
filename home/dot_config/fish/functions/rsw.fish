function rsw --description 'Start a background rsync-on-change watcher: rsw <source> <destination>'
    if test (count $argv) -ne 2
        echo "Usage: rsw <source> <destination>"
        return 1
    end

    set -l src (string replace -r '/$' '' -- $argv[1])
    set -l dest $argv[2]

    # Reuse one SSH connection per login, so 1Password only prompts once.
    set -l sockets $XDG_RUNTIME_DIR
    test -n "$sockets"; or set sockets ~/.ssh/sockets
    mkdir -p $sockets
    set -l rsh "ssh -o ControlMaster=auto -o ControlPath=$sockets/rsw-%r@%h:%p -o ControlPersist=yes"

    setsid --fork env RSYNC_RSH="$rsh" bash -c 'rsync -a "$1/" "$2"; while inotifywait -r -q -e modify,create,delete,move "$1"; do rsync -a "$1/" "$2"; done' rsw-watch $src $dest >/dev/null 2>&1
    echo "Watching $src -> $dest"
end
