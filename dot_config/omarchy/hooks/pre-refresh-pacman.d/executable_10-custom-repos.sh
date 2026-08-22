#!/bin/bash
# Splice third-party repo sections into /etc/pacman.conf. Inlined rather than
# Include'd because cachyos-kernel-manager parses pacman.conf with a plain INI
# reader and never follows Include lines.
#
#   ~/.config/pacman/custom-repos-head.conf -> above [core]  repos that should win over Arch
#   ~/.config/pacman/custom-repos-tail.conf -> end of file   repos that must never shadow Arch
#
# Safe to re-run any time: existing marker blocks are removed and re-spliced
# from the current snippets, so editing a snippet + running this applies it.
# `--check` only reports: exit 0 if pacman.conf is current, 2 if it would
# change. Never escalates.
#
# `omarchy refresh pacman` overwrites /etc/pacman.conf from the channel
# template, runs this hook, then `pacman -Syyuu`.
set -e

check=0; [[ ${1:-} == --check ]] && check=1

CONF=/etc/pacman.conf
HEAD=$HOME/.config/pacman/custom-repos-head.conf
TAIL=$HOME/.config/pacman/custom-repos-tail.conf

[[ -r $HEAD ]] || HEAD=
[[ -r $TAIL ]] || TAIL=
[[ -n $HEAD || -n $TAIL ]] || exit 0

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
awk -v head="$HEAD" -v tail="$TAIL" '
  function emit(f) {
    out[++n] = "# >>> " f " (inlined by pre-refresh-pacman hook) >>>"
    while ((getline l < f) > 0) out[++n] = l
    close(f)
    out[++n] = "# <<< " f " <<<"
  }
  # drop any previously spliced block (and the blank line we added after/before it)
  /^# >>> .* >>>$/ { skip = 1; next }
  /^# <<< .* <<<$/ { skip = 0; eat_blank = 1; next }
  skip { next }
  eat_blank && /^$/ { eat_blank = 0; next }
  { eat_blank = 0 }
  head && /^\[core\]/ && !done { emit(head); out[++n] = ""; done = 1 }
  { out[++n] = $0 }
  END {
    while (n && out[n] == "") n--          # trim trailing blanks so tail block never drifts
    for (i = 1; i <= n; i++) print out[i]
    if (tail) { n0 = n; out[++n] = ""; emit(tail); for (i = n0 + 1; i <= n; i++) print out[i] }
  }
' "$CONF" > "$tmp"

cmp -s "$tmp" "$CONF" && exit 0
(( check )) && exit 2
echo "pre-refresh-pacman: splicing${HEAD:+ $HEAD above [core]}${TAIL:+ $TAIL at end}"
sudo install -m 644 "$tmp" "$CONF"
