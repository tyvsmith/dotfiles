#!/bin/bash
# Splice third-party repo sections into /etc/pacman.conf. Inlined rather than
# Include'd because cachyos-kernel-manager parses pacman.conf with a plain INI
# reader and never follows Include lines.
#
#   ~/.config/pacman/custom-repos-head.conf -> before all repos  repos that should win over Omarchy and Arch
#   ~/.config/pacman/custom-repos-tail.conf -> end of file   repos that must never shadow Arch
#
# Safe to re-run any time: existing marker blocks are removed and re-spliced
# from the current snippets, so editing a snippet + running this applies it.
# `--check` only reports: exit 0 if pacman.conf is current, 2 if it would
# change, 1 if marker blocks need repair. Never escalates.
#
# `omarchy refresh pacman` overwrites /etc/pacman.conf from the channel
# template, runs this hook, then `pacman -Syyuu`.
set -euo pipefail

check=0
output=""

CONF=/etc/pacman.conf
SYSTEM_MIRRORS=/etc/pacman.d/arch-mirrorlist
case ${1:-} in
  --check) check=1 ;;
  --render)
    [[ $# == 3 ]] || exit 1
    [[ $2 != "$3" && ! $2 -ef $3 && ! $2 -ef $3.mirrors ]] || exit 1
    CONF=$2
    output=$3
    ;;
  "") ;;
  *) echo "Usage: $0 [--check | --render INPUT OUTPUT]" >&2; exit 1 ;;
esac
HEAD=$HOME/.config/pacman/custom-repos-head.conf
TAIL=$HOME/.config/pacman/custom-repos-tail.conf
OPTIONS=$HOME/.config/pacman/options.conf
MIRRORS=$HOME/.config/pacman/arch-mirrorlist

[[ -r $HEAD ]] || HEAD=
[[ -r $TAIL ]] || TAIL=
[[ -r $OPTIONS ]] || OPTIONS=
[[ -r $MIRRORS ]] || MIRRORS=

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
tmp=$scratch/pacman.conf
mirror_target=$SYSTEM_MIRRORS
if [[ -n $output ]]; then mirror_target=$(realpath -m -- "$output.mirrors"); fi
# Validate and install the same snapshot, never re-read the user source as root.
if [[ -n $MIRRORS ]]; then
  cp -- "$MIRRORS" "$scratch/mirror-source"
  MIRRORS=$scratch/mirror-source
fi
awk -v head="$HEAD" -v tail="$TAIL" -v options="$OPTIONS" -v mirrors="$MIRRORS" \
    -v mirror_target="$mirror_target" -v mirror_output="$scratch/mirrors" '
  function managed_sections(file, line) {
    while (file && (getline line < file) > 0) {
      if (line ~ /^[[:space:]]*\[/) {
        gsub(/[[:space:]]/, "", line)
        if (line ~ /^\[(options|omarchy|core|extra|multilib)\]$/) exit 1
        managed[line] = 1
      }
    }
    if (file) close(file)
  }
  BEGIN {
    managed_sections(head)
    managed_sections(tail)
    while (options && (getline line < options) > 0) {
      if (line ~ /^[[:space:]]*(#|$)/) continue
      if (line !~ /^[A-Za-z]+[[:space:]]*=/) exit 1
      key = line; sub(/[[:space:]]*=.*/, "", key)
      overrides[key] = 1
    }
    if (options) close(options)
    while (mirrors && (getline line < mirrors) > 0) {
      if (line ~ /^[[:space:]]*(#|$)/) continue
      if (line !~ /^Server[[:space:]]*=[[:space:]]*https:\/\//) exit 1
      print line > mirror_output
      mirror_count++
    }
    if (mirrors) close(mirrors)
    if (mirrors && !mirror_count) exit 1
  }
  function reject() {
    print "pre-refresh-pacman: malformed repo blocks; repair pacman.conf before retrying" > "/dev/stderr"
    failed = 1
    exit 1
  }
  function emit(f) {
    out[++n] = "# >>> " f " (inlined by pre-refresh-pacman hook) >>>"
    while ((getline l < f) > 0) out[++n] = l
    close(f)
    out[++n] = "# <<< " f " <<<"
  }
  # drop any previously spliced block (and the blank line we added after/before it)
  /^# >>> .* >>>$/ {
    if (skip) reject()
    block = $0
    sub(/^# >>> /, "", block)
    sub(/ \(inlined by pre-refresh-pacman hook\) >>>$/, "", block)
    skip = 1
    next
  }
  /^# <<< .* <<<$/ {
    if (!skip || $0 != "# <<< " block " <<<") reject()
    skip = 0; eat_blank = 1; next
  }
  # Omarchy migrations can move the distro section inside our comment markers.
  skip && /^[[:space:]]*\[omarchy\][[:space:]]*$/ { reject() }
  skip { next }
  eat_blank && /^$/ { eat_blank = 0; next }
  { eat_blank = 0 }
  /^[[:space:]]*\[/ {
    original_section = $0; gsub(/[[:space:]]/, "", original_section)
    managed_original = original_section in managed
  }
  managed_original { next }
  head && /^[[:space:]]*\[[^]]+\]/ && !/^[[:space:]]*\[options\]/ && !done {
    emit(head); out[++n] = ""; done = 1
  }
  /^[[:space:]]*\[/ {
    section = $0; gsub(/[[:space:]]/, "", section)
    out[++n] = $0
    if (section == "[options]" && options) emit(options)
    if (mirror_count && section ~ /^\[(core|extra|multilib)\]$/)
      out[++n] = "Include = " mirror_target
    next
  }
  section == "[options]" {
    key = $0; sub(/^[[:space:]]*/, "", key); sub(/[[:space:]]*=.*/, "", key)
    if (key in overrides) next
  }
  mirror_count && section ~ /^\[(core|extra|multilib)\]$/ && /^[[:space:]]*(Server|Include)[[:space:]]*=/ { next }
  { out[++n] = $0 }
  END {
    if (failed) exit 1
    if (skip) reject()
    while (n && out[n] == "") n--          # trim trailing blanks so tail block never drifts
    if (head && !done) { out[++n] = ""; emit(head) }
    for (i = 1; i <= n; i++) print out[i]
    if (tail) { n0 = n; out[++n] = ""; emit(tail); for (i = n0 + 1; i <= n; i++) print out[i] }
  }
' "$CONF" > "$tmp"

if [[ -n $output ]]; then
  [[ ! -s $scratch/mirrors ]] || install -m 644 "$scratch/mirrors" "$mirror_target"
  install -m 644 "$tmp" "$output"
  exit 0
fi
mirrors_current=1
if [[ -s $scratch/mirrors ]]; then
  if ! cmp -s "$scratch/mirrors" "$SYSTEM_MIRRORS" ||
    [[ $(stat -c '%u:%g:%a' "$SYSTEM_MIRRORS" 2>/dev/null) != 0:0:644 ]]; then
    mirrors_current=0
  fi
fi
if cmp -s "$tmp" "$CONF" && (( mirrors_current )); then exit 0; fi
(( check )) && exit 2
echo "pre-refresh-pacman: splicing${HEAD:+ $HEAD before all repositories}${TAIL:+ $TAIL at end}"
if [[ -s $scratch/mirrors ]]; then
  sudo install -o root -g root -m 644 "$scratch/mirrors" "$SYSTEM_MIRRORS"
fi
sudo install -o root -g root -m 644 "$tmp" "$CONF"
