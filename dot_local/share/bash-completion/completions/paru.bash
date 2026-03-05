# User override for paru completion
# Fixes: paru -Pc outputs binary data containing null bytes for some AUR
# packages, causing "bash: warning: command substitution: ignored null byte
# in input" on every Tab completion.
#
# Strategy: source the system completion file, then redefine _paru_pkg to
# strip null bytes from the paru -Pc output.

# Source the system paru completion (provides _paru, _paru_pkg, etc.)
_paru_system_completion="/usr/share/bash-completion/completions/paru.bash"
if [[ -f "$_paru_system_completion" ]]; then
  source "$_paru_system_completion"
else
  return 0
fi
unset _paru_system_completion

# Override _paru_pkg to strip null bytes from paru -Pc output
_paru_pkg() {
  [ -z "$cur" ] && _pacman_pkg Slq && return
  _arch_compgen "$(command paru -Pc | tr -d '\0')"
}
