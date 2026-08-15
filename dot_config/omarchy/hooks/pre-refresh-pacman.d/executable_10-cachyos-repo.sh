#!/bin/bash
# Re-add the CachyOS repo Include ABOVE [core] so its znver4-optimized builds
# win over stock Arch.
#
# `omarchy refresh pacman` overwrites /etc/pacman.conf wholesale from the
# channel template, then runs this hook, then `pacman -Syyuu`. Without this the
# upgrade would resolve every package against plain Arch.
#
# Runs as the invoking user with a warm sudo cache (refresh-pacman just sudo'd).

set -e

CONF=/etc/pacman.conf
SNIPPET=/etc/pacman.d/cachyos-repos.conf
MARKER="Include = $SNIPPET"

[[ -r $SNIPPET ]] || exit 0
grep -qxF "$MARKER" "$CONF" && exit 0

echo "pre-refresh-pacman: inserting $MARKER above [core]"
sudo sed -i "0,/^\[core\]/s||$MARKER\n\n[core]|" "$CONF"
