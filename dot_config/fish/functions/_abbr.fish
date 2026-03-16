# Create abbreviation only if the target command exists.
# Usage: _abbr alias command [args...]
# Falls through to `abbr --add` when the command (argv[2]) is installed.
function _abbr
    command -q $argv[2]; and abbr --add $argv
end
