function __ssh_interactive --description 'True when the ssh args describe an interactive session (destination, no remote command)'
    # The letters are the ssh(1) options that consume a value, so their
    # arguments are not mistaken for the destination.
    set -l value_opts BbcDEeFIiJLlmOoPpQRSWw
    set -l args $argv
    set -l dest ''
    set -l opts_done 0

    while set -q args[1]
        set -l arg $args[1]
        set -e args[1]

        if test $opts_done -eq 0; and test "$arg" = --
            set opts_done 1
        else if test $opts_done -eq 0; and string match -qr '^-.' -- $arg
            set -l letters (string sub -s 2 -- $arg | string split '')
            set -l n (count $letters)
            for i in (seq $n)
                if string match -q -- "*$letters[$i]*" $value_opts
                    # The value is glued to the letter (-p2222) unless the letter
                    # ends the argument, in which case it consumes the next one.
                    test $i -eq $n; and set -e args[1]
                    break
                end
            end
        else if test -z "$dest"
            set dest $arg
        else
            return 1
        end
    end

    test -n "$dest"; or return 1

    # A RemoteCommand from ssh_config or -o replays on reconnect just like a
    # positional command; ssh -G resolves the effective configuration for this
    # exact invocation without connecting. Fail closed when it cannot resolve.
    # The explicit "none" cancels a configured command.
    set -l resolved (command ssh -G $argv 2>/dev/null); or return 1
    not string match -qri '^remotecommand (?!none$)' -- $resolved
end
