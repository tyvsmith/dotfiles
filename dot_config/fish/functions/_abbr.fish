# Create abbreviation only if the target command exists.
# Usage: _abbr alias command [args...]
# Falls through to `abbr --add` when the command (argv[2]) is installed.
function _abbr
    set -l cmd (string split ' ' -- $argv[2])[1]
    command -q $cmd; and abbr --add $argv
end
