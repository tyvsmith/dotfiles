# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io/), using Fish shell. Targets macOS and Linux (including immutable distros like Bazzite/Fedora Silverblue).

## Common Commands

```bash
# Apply dotfile changes
chezmoi apply

# Preview changes before applying
chezmoi diff

# Add a new file to management
chezmoi add ~/.config/some/file

# Go to chezmoi source directory
chezmoi cd

# Update from remote and apply
chezmoi update

# Re-run package installs (triggered automatically when packages.yaml changes)
chezmoi apply
```

## Architecture

### Chezmoi Naming Conventions
- `dot_` prefix → becomes `.` (e.g., `dot_config` → `.config`)
- `private_` prefix → file permissions set to 0600
- `.tmpl` suffix → Go template, rendered with machine-specific data
- `run_once_` prefix → executed once on `chezmoi apply`

### Profile-Driven Configuration

Machine setup is driven by a single **profile** selected via environment variable or `install.sh`:
```bash
DOTFILES_PROFILE=arch chezmoi init
./install.sh --profile macos-work
```

Each profile (defined in `.chezmoidata/profiles.yaml`) fully specifies:
- **`tier`**: 1 = core CLI, 2 = containers, 3 = dev SDKs, 4 = hardware, 5 = basic UI, 6 = extended UI, 7 = gaming
- **Package managers**: `brew`, `pacman`, `apt`, `dnf`, `rpm_ostree`, `flatpak`
- **`work`**: work machine (system SSH agent, corporate configs)
- **`decrypt`**: enable age decryption of private configs

If no profile is specified, auto-detects from distro (macOS → `macos-work`, Arch → `arch-desktop`, etc.).

**Available profiles:**

| Profile | Tier | Pkg Managers | Work | Decrypt | Description |
|---|---|---|---|---|---|
| `macos-work` | 7 | brew | yes | yes | Work Mac — corporate dev + GUI |
| `arch-desktop` | 7 | pacman, flatpak | | yes | Arch Linux desktop |
| `debian-server` | 1 | apt | | | Debian/Ubuntu server — CLI only |
| `debian-devpod` | 3 | apt | | yes | Debian/Ubuntu dev |
| `silverblue` | 7 | brew, rpm_ostree, flatpak | | yes | Silverblue/Bazzite immutable |

**Package tiers:**
- **Tier 1 (ALL machines):** Core CLIs — shell (fish, atuin, zoxide), modern CLI tools (eza, bat, fd, ripgrep, etc.), git, neovim, tmux, essential utils
- **Tier 2 (tier >= 2):** Containers — docker, docker-compose, podman, distrobox, lazydocker
- **Tier 3 (tier >= 3):** Development SDKs — mise, uv, build tools (imagemagick, p7zip), AI tools (llm, claude-code), dev utilities (shellcheck, tokei, hyperfine)
- **Tier 4 (tier >= 4):** Hardware — bluetui and other hardware interaction tools
- **Tier 5 (tier >= 5):** Basic UI — fonts, VS Code, ghostty, browser, 1Password, obsidian
- **Tier 6 (tier >= 6):** Extended UI — JetBrains, Discord, media apps, macOS extras
- **Tier 7 (tier >= 7):** Gaming — Steam

### OS Detection in Templates
Templates use `{{ if eq .chezmoi.os "darwin" }}` for macOS-specific and `{{ else }}` for Linux paths (e.g., Homebrew paths, SSH agent sockets).

### Package Management

Packages are defined once in `.chezmoidata/packages.yaml` and installed via platform-specific package managers:
- **macOS**: Homebrew formulas + casks
- **Arch Linux**: paru (handles both official repos and AUR)
- **Debian/Ubuntu**: apt (native repos only)
- **Fedora**: dnf
- **Immutable Fedora (Silverblue/Bazzite)**: rpm-ostree (for OS-integrated packages only)
- **Linux GUI**: Flatpak (Flathub) or AppImage (GitHub releases)

The YAML key is the default package name for all package managers. Native manager fields (`brew`, `arch`, `apt`, `dnf`) are **tri-state**:
- absent → available, use YAML key as package name
- string → available, use string as package name (e.g., `arch: python-llm`)
- `false` → excluded from this manager (e.g., `brew: false`)

Brew modifier fields:
- `brew_cask: true` — marks as Homebrew cask (macOS-only); name from `brew:` or YAML key; cascades to next manager on Linux
- `brew_tap:` — Homebrew tap required before install

Opt-in manager fields are present when available:
- `rpm_ostree:` — rpm-ostree package (`true` = use YAML key, string = override name; for immutable Fedora)
- `flatpak:` — Flatpak app ID
- `appimage:` — GitHub repo (`owner/name`) for AppImage download

Cascade order: `brew → brew_cask → pacman → apt → dnf → rpm_ostree → flatpak → appimage`. Each package goes to the first enabled manager that can handle it, determined at template time by `.chezmoitemplates/cascade-filter`. Each manager has its own `run_onchange_*` script with a profile guard that renders to `exit 0` when the manager is not enabled.

**Debian/Ubuntu apt availability:**
The apt install script uses runtime `apt-cache` checks to determine package availability, so it works correctly across different Debian/Ubuntu versions without static exclusion lists. Packages available in Ubuntu 24.04 but missing in Debian Bookworm (e.g., eza, sd, git-delta, gping, yq, hyperfine) will be installed where available and skipped with warnings where not.

### Key Files
- `.chezmoidata/packages.yaml` - Single source of truth for all package definitions across platforms
- `.chezmoidata/profiles.yaml` - Machine profile definitions (tier, pkg managers, work, decrypt)
- `.chezmoitemplates/cascade-filter` - Shared cascade logic for package manager selection
- `dot_config/fish/fish_plugins.tmpl` - Fisher plugin manifest (OS-specific)
- `dot_config/git/config.tmpl` - Git config with delta pager, useful aliases

### Install Scripts

Scripts use category-based numeric prefixes with gaps for future expansion:

```
00-09  Setup & prereqs
10-19  Native package managers
20-29  (reserved)
30-39  Containerized/sandboxed package managers
40-49  Custom binaries (future)
50-59  Language stacks & deps (future)
60-69  Shell configuration
70+    Future custom
```

| Script | Description |
|---|---|
| `run_before_00-decrypt.sh.tmpl` | Ensures age key exists (1Password or manual) |
| `run_onchange_00-setup-directories.sh` | Creates required dirs (~/.ssh/sockets, etc.) |
| `run_onchange_10-install-packages-homebrew.sh.tmpl` | Homebrew formulas (+ Homebrew install on Linux) |
| `run_onchange_11-install-packages-cask.sh.tmpl` | Homebrew casks (macOS only) |
| `run_onchange_12-install-packages-pacman.sh.tmpl` | Arch Linux packages via paru |
| `run_onchange_13-install-packages-apt.sh.tmpl` | Debian/Ubuntu packages via apt |
| `run_onchange_14-install-packages-dnf.sh.tmpl` | Fedora packages via dnf |
| `run_onchange_15-install-packages-rpm-ostree.sh.tmpl` | Immutable Fedora packages via rpm-ostree |
| `run_onchange_30-install-packages-flatpak.sh.tmpl` | Flatpak GUI apps (Linux, tier 4+) |
| `run_onchange_31-install-packages-appimage.sh.tmpl` | AppImage downloads (Linux, last resort) |
| `run_onchange_60-install-fisher.sh.tmpl` | Installs Fisher and Fish plugins |
| `run_onchange_61-configure-tide.sh.tmpl` | Configures Tide prompt |

### Philosophy
- All modern CLI tools are abbreviated over old commands (`ls→eza`, `cat→bat`, `rm→trash`, `diff→difft`, `df→duf`, `du→dust`, `ping→gping`, `grep→rg`, `find→fd`, `sed→sd`, `curl→xh`). Since abbreviations expand visibly before running, this forces learning the new syntax.
- Shorthand abbreviations for longer tool names: `lg→lazygit`, `br→broot`
- Shell greeting shows random CLI tips to teach modern tool usage
