# Omarchy channels with CachyOS repositories

Keep CachyOS first, change only the Omarchy package channel, and use live Arch
for packages the custom repositories do not supply.

Policy lives in `~/.config/pacman/`:

- `custom-repos-head.conf`: repositories before Omarchy
- `custom-repos-tail.conf`: repositories after Arch
- `arch-mirrorlist`: five ranked live Arch servers, including the rolling Omarchy mirror
- `options.conf`: explicit local pacman option overrides

The pre-refresh hook inserts that policy into the selected channel template.
`core`, `extra` and `multilib` include `/etc/pacman.d/arch-mirrorlist`, so replacing
`/etc/pacman.d/mirrorlist` no longer changes their source. CachyOS keeps its
own system mirrorlists. The hook validates a snapshot of the managed Arch
list and installs it as root-owned data before updating pacman.conf. Mirror
ranking changes belong in `~/.config/pacman/arch-mirrorlist`; apply them through
the hook after review. User-file edits cannot change the active root copy. Use
`mirror.omarchy.org` with rolling Arch mirrors, never the RC or stable snapshot
mirrors. The `[omarchy]` package channel remains independent. Remove obsolete package holds from
`options.conf` explicitly.

Use the normal channel menu or `omarchy channel set stable|rc|edge`.
Omarchy writes the selected channel defaults, runs `pre-refresh-pacman` to
restore this policy, then updates packages through its standard commands.
No CLI overrides or custom transaction preflight are needed.

Package compatibility remains separate from configuration preservation.
A failed package transaction can leave the selected channel configuration
installed; resolve the conflict before retrying. Channel switching permits
downgrades, including packages from custom repositories.

RC receives final releases: Omarchy builds final release packages into RC,
then promotes them to stable. Public RC tags are not required for patch
releases. See [upstream release process](https://github.com/omacom/omarchy-pkgs/blob/master/docs/releases.md).

For inspection, `10-custom-repos.sh --render INPUT OUTPUT` writes a config
and an adjacent `OUTPUT.mirrors` snapshot, without sudo. The rendered config
includes that snapshot; normal application includes the root-owned system file.
