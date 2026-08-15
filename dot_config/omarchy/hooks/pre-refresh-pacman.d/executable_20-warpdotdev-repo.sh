#!/bin/bash
# Re-add the Warp terminal repo Include at the END of /etc/pacman.conf, so it
# sits below Arch and Omarchy in precedence and only supplies its own packages.
#
# Appended rather than inserted above [core] deliberately: this repo should
# never shadow a distro package.
#
# Note: a trailing Include is the fragile position. The 3.8.5 -> 4.0 upgrade
# carried over the above-[core] Include but silently dropped this one, because
# it rebuilds pacman.conf from a template that ends with the [omarchy] section.
# That is exactly what this hook exists to repair.

set -e

CONF=/etc/pacman.conf
SNIPPET=/etc/pacman.d/warpdotdev-repo.conf
MARKER="Include = $SNIPPET"

[[ -r $SNIPPET ]] || exit 0
grep -qxF "$MARKER" "$CONF" && exit 0

echo "pre-refresh-pacman: appending $MARKER"
printf '\n%s\n' "$MARKER" | sudo tee -a "$CONF" >/dev/null
