# Wrap ssh to clean up the terminal and reconnect when a connection drops
# (port of omarchy's default/bash/fns/ssh-reconnect).
#
# A remote tmux, herdr, or editor arms terminal modes over the SSH pipe (mouse
# tracking, focus reporting, the alternate screen) that only it can disarm. If
# the connection dies instead of exiting cleanly, those modes stay armed on the
# local terminal, and every mouse move floods the prompt with escape junk.
#
# Work profiles set __ssh_plain_shell (zz_00_work.fish) so ssh runs with
# SHELL=/bin/sh: `Match exec` blocks in ~/.ssh/config would otherwise start a
# fish per evaluation.
function ssh --wraps=ssh --description 'ssh with terminal cleanup and auto-reconnect'
    set -l ssh_env
    set -q __ssh_plain_shell; and set ssh_env SHELL=/bin/sh

    set -l started (date +%s)
    command env $ssh_env ssh $argv
    set -l rc $status

    isatty stdout; or return $rc
    __ssh_disarm

    # Reconnect only when an interactive session drops: ssh exits 255 for
    # transport failures, but a fast 255 with no established session is a
    # connect/auth failure, a remote command's own 255 passes through
    # indistinguishably and must not replay its side effects, and redirected
    # stdin would feed the remaining piped input to a fresh remote shell.
    if test $rc -ne 255
        or not isatty stdin
        or not __ssh_interactive $argv
        or test (math (date +%s) - $started) -lt 30
        return $rc
    end

    # Ctrl-C reaches the foreground ssh and then cancels this loop. Keep
    # retrying fast failures, since a rebooting server refuses connections too.
    while true
        echo "Connection lost. Reconnecting (Ctrl-C to stop)..."
        sleep 2
        command env $ssh_env ssh $argv
        set rc $status
        __ssh_disarm
        test $rc -ne 255; and return $rc
    end
end
