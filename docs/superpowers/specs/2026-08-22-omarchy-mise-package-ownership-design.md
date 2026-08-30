# Omarchy, mise, and Package Ownership Design

**Date:** 2026-08-22

**Status:** Approved for implementation planning

## Goal

Keep the cross-platform dotfiles declarative without fighting Omarchy 4's lazy mise wrappers. Omarchy should own installation and activation of its wrapped command-line agents on the Omarchy host. Chezmoi should continue to own stable runtime policy, native application/package declarations, and generic-Arch behavior.

## Current State

The active machine is Omarchy 4.0.0-1 using the `arch-desktop` Chezmoi profile. The relevant state is:

- Chezmoi manages `~/.config/mise/config.toml` from `dot_config/mise/config.toml.tmpl`.
- The source template declares Bun, Node, Rust, Go, Java, Claude, and Codex.
- Omarchy installs lazy wrappers in `~/.local/bin`. A wrapper invokes `mise use -g`, which writes the selected tool into `~/.config/mise/config.toml`, then executes the mise-managed binary.
- The live mise config consequently contains more tools than the Chezmoi template: OpenCode, GitHub CLI, ghui, Grok, pi, and oh-my-pi are present in addition to the source-managed tools.
- Native `github-cli` and `gemini-cli` packages are also installed. No package is to be removed in this iteration.
- `.chezmoidata/packages.yaml` already excludes `gh` from pacman and leaves Claude, Codex, OpenCode, and Gemini package entries disabled. It also contains unrelated uncommitted user edits that must not be overwritten or committed accidentally.
- The Arch package installer currently sends both configured-repository and AUR packages through `paru`.

## Ownership Model

### Omarchy-owned mutable state

Omarchy owns:

- `~/.local/bin` wrappers created by `omarchy-mise-install`.
- `~/.config/mise/config.toml`, which is the write target of the wrappers' `mise use -g` calls.
- The set of wrapper-backed tools the user has launched or selected.

Chezmoi must not install, edit, replace, or remove these wrappers. It must stop rendering the mutable global mise file.

### Chezmoi-owned declarative state

Chezmoi owns a mise drop-in at `~/.config/mise/conf.d/10-dotfiles.toml` containing:

- Bun, Node, Rust, Go, and Java global runtime defaults.
- The existing policy of leaving Python unmanaged globally.
- The existing `go_set_goroot = false` compatibility setting.
- The explicit mise npm backend choice `npm.package_manager = "aube"`.
- Claude and Codex only on non-Omarchy development profiles, preserving the current cross-platform behavior while avoiding ownership overlap on Omarchy.

Mise supports global `conf.d/*.toml` fragments, while global write operations continue to target `config.toml`. This creates a clean boundary between declarative defaults and Omarchy's mutable selections.

### Package-manager ownership

Use this policy:

| Artifact | Owner | Examples |
|---|---|---|
| OS, driver, service, shared library, desktop application | Configured repository via pacman/Omarchy | PipeWire, Docker, Ghostty, Neovim, uv |
| Package unavailable from configured repositories | AUR helper | resticprofile, hyprmod, selected `-bin` packages |
| Language runtime requiring project/global version selection | mise core backend | Node, Bun, Go, Java, Rust |
| Omarchy-provided lazy CLI/agent | Omarchy wrapper plus mise backend | Claude, Codex, OpenCode, Gemini, ghui |
| Project dependency | Project-native manager | `uv`, Bun, npm, Cargo, Go modules |

`omarchy pkg add` and `omarchy pkg aur add` are preferred on Omarchy because they are its stable user-facing interface. Generic Arch continues to use pacman and paru directly.

## Package Routing

Do not add a static `aur:` field. A package can be available from an Omarchy or CachyOS repository on one machine and require the AUR on another. The Arch installer should classify each candidate at execution time:

1. If `pacman -Si` succeeds, it is a configured-repository package.
2. Otherwise, if the selected AUR helper's `-Si` succeeds, it is an AUR package.
3. Otherwise, report it as missing.

On Omarchy, install the resulting groups with `omarchy pkg add` and `omarchy pkg aur add`. On generic Arch, use `sudo pacman -S --needed --noconfirm` and `paru -S --needed --noconfirm`.

## Mise npm Backend

Keep Bun globally available, but do not make Bun the installer for mise's `npm:` backend. Mise 2026.8 uses embedded aube by default in automatic mode; configuring `aube` explicitly makes that choice reproducible and keeps npm-backed CLI installs isolated. Projects remain free to use Bun according to their own lockfile or `packageManager` declaration.

Do not globally disable mise's release-age protection and do not add a global lockfile in this iteration. Omarchy deliberately bypasses the release delay in its wrappers for its fast-moving tools. A cross-platform global lockfile would add platform-specific maintenance without solving the ownership conflict.

## Existing Installed State

The first implementation is non-destructive:

- Keep native `github-cli`, `gemini-cli`, `nodejs`, `npm`, `uv`, and `mise` installed.
- Keep `paru` installed even though Omarchy ships and uses `yay`.
- Keep all installed mise tools and cached runtime versions.
- Do not run `mise unuse`, `mise uninstall`, `mise prune`, `pacman -R`, `yay -R`, or `paru -R`.

A read-only audit command will expose command resolution, pacman ownership, wrapper presence, and mise resolution. Cleanup becomes a separately approved follow-up after the split configuration has run successfully.

## Safety and Upgrade Behavior

- Never modify `/usr/share/omarchy` or the generated wrappers.
- Preserve the live `~/.config/mise/config.toml` when Chezmoi stops managing it.
- Apply the new drop-in by target path first; do not run an unrestricted `chezmoi apply` as the migration step.
- Preserve the current uncommitted `.chezmoidata/packages.yaml` changes.
- Omarchy upgrades may regenerate wrappers without affecting the Chezmoi drop-in.
- Chezmoi applies may update the drop-in without erasing tools selected through Omarchy.

## Verification

Verification must demonstrate:

- The new drop-in renders as valid TOML.
- `mise config ls` includes both `~/.config/mise/config.toml` and the Chezmoi drop-in.
- The live mutable config retains its current wrapper-added tools.
- Fish resolves installed mise tools ahead of wrappers after activation, while uninstalled tools still reach their Omarchy wrapper.
- The rendered Arch installer contains distinct repository and AUR routes.
- The package manifest still excludes competing agent packages.
- No packages or mise installations were removed.

## Upstream Basis

- [Omarchy's current development-tools guidance](https://github.com/basecamp/omarchy/blob/quattro/manual/18-development-tools.md)
- [Omarchy wrapper recursion issue and `mise exec` fix](https://github.com/basecamp/omarchy/issues/6349)
- [Omarchy wrapper stdout/protocol issue](https://github.com/basecamp/omarchy/issues/6908)
- [mise configuration and global config behavior](https://mise.jdx.dev/configuration.html)
- [mise npm backend and embedded aube](https://mise.jdx.dev/dev-tools/backends/npm.html)
- [mise backend architecture](https://mise.jdx.dev/dev-tools/backend_architecture)

