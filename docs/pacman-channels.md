# Omarchy channels with CachyOS repositories

Keep CachyOS first, change only the Omarchy package channel, and use live Arch
for packages the custom repositories do not supply.

Policy lives in `~/.config/pacman/`:

- `custom-repos-head.conf`: repositories before Omarchy
- `custom-repos-tail.conf`: repositories after Arch
- `arch-mirrorlist`: five ranked live Arch servers, including the rolling Omarchy mirror
- `options.conf`: explicit local pacman option overrides

The pre-refresh hook inserts that policy into the selected channel template.
`core`, `extra` and `multilib` include the same managed `arch-mirrorlist`, so replacing
`/etc/pacman.d/mirrorlist` no longer changes their source. CachyOS keeps its
own system mirrorlists. Mirror ranking changes belong in `arch-mirrorlist`;
capture them with chezmoi afterward. The include points to the absolute user
configuration path; keep that file readable and present. Use
`mirror.omarchy.org` with rolling Arch mirrors, never the RC or stable snapshot
mirrors. The `[omarchy]` package channel remains independent. Remove obsolete package holds from
`options.conf` explicitly.

Use the normal channel menu or `omarchy channel set stable|rc|edge`.
The PATH override for `omarchy-refresh-pacman` stages the configuration,
syncs signed databases in a temporary directory, and prepares both the
upgrade and release/dev package swap. It declines installation during these
checks. Dependency failures, unknown package choices and additional custom
pre-refresh hooks stop the switch before it writes `/etc`.

Preview without sudo or system changes:

```bash
omarchy-refresh-pacman --preview stable
```

The CLI override also guards `omarchy refresh pacman`. Calling the packaged
`/usr/bin/omarchy-refresh-pacman` directly bypasses preflight, although the
policy hook still runs. These overrides must be ahead of `/usr/bin` in PATH.
Development-checkout switching is outside this guard: upstream links the
checkout before refreshing repositories.

Preflight is not a guarantee that installation succeeds. Repositories may
change afterward; archive/file conflicts and package scripts are checked
only during installation. After a successful check, upstream-style backups
and the normal Omarchy package update run. A later failure can leave the
new repository configuration installed. No package hold is added for
Hyprland titlebars; an incompatible downgrade must be resolved explicitly.

RC receives final releases: Omarchy builds final release packages into RC,
then promotes them to stable. Public RC tags are not required for patch
releases. See [upstream release process](https://github.com/omacom/omarchy-pkgs/blob/master/docs/releases.md).
