#!/bin/bash
# Rebuild hyprpm plugins when hyprland or a hypr* library changed under them.
#
# hyprpm only refreshes its cached headers when the hyprland commit hash
# changes. A library bump alone (e.g. aquamarine 0.14 -> 0.15 with hyprland
# rebuilt at the same tag) leaves the cached headers stale, `hyprpm update`
# rebuilds against them, and every plugin then fails to load with
# "[he] Version mismatch" while `hyprpm reload` still claims success.
#
# Compare the installed headers against hyprpm's cached copy using the same
# fields Hyprland hashes into its plugin ABI string (commit + major.minor of
# each library) and force a rebuild when they differ.
set -euo pipefail

cached="/var/cache/hyprpm/$(id -un)/headersRoot/include/hyprland/src/version.h"
installed="/usr/include/hyprland/src/version.h"
[[ -f "$cached" && -f "$installed" ]] || exit 0
command -v hyprpm >/dev/null 2>&1 || exit 0

abi() {
    local file=$1
    ver() { sed -nE "s/^#define $1 +\"([0-9]+\\.[0-9]+).*/\\1/p" "$file"; }
    printf '%s_aq_%s_hu_%s_hg_%s_hc_%s_hlg_%s\n' \
        "$(sed -nE 's/^#define GIT_COMMIT_HASH +"([0-9a-f]+)".*/\1/p' "$file")" \
        "$(ver AQUAMARINE_VERSION)" "$(ver HYPRUTILS_VERSION)" \
        "$(ver HYPRGRAPHICS_VERSION)" "$(ver HYPRCURSOR_VERSION)" \
        "$(ver HYPRLANG_VERSION)"
}

want=$(abi "$installed")
have=$(abi "$cached")
if [[ "$want" == "$have" ]]; then
    exit 0
fi

echo "hyprpm: cached headers are stale, forcing plugin rebuild"
echo "  cached:    $have"
echo "  installed: $want"
hyprpm update -f
