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

# Install packages (macOS only - auto-detects distro on Linux)
brew bundle --file="$(chezmoi source-path)/Brewfile"
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
- **`tier`**: 1 = CLI tools only, 2 = + dev tools, 3 = + GUI apps
- **Package managers**: `brew`, `pacman`, `apt`, `dnf`, `flatpak`
- **`is_work`**: work machine (system SSH agent, corporate configs)
- **`decrypt`**: enable age decryption of private configs

If no profile is specified, auto-detects from distro (macOS → `macos-personal`, Arch → `arch`, etc.).

**Available profiles:**

| Profile | Tier | Pkg Managers | Work | Decrypt | Description |
|---|---|---|---|---|---|
| `macos-personal` | 3 | brew | | yes | Personal Mac — full dev + GUI |
| `macos-work` | 3 | brew | yes | yes | Work Mac — corporate dev + GUI |
| `arch` | 3 | pacman, flatpak | | yes | Arch Linux desktop |
| `debian-server` | 1 | apt | | | Debian/Ubuntu server — CLI only |
| `debian-dev` | 2 | apt | | yes | Debian/Ubuntu dev |
| `debian-brew` | 2 | brew, flatpak | | yes | Debian/Ubuntu dev + Homebrew |
| `devpod` | 2 | brew | yes | | Work devpod |
| `fedora` | 3 | dnf, flatpak | | yes | Fedora Workstation |
| `silverblue` | 3 | brew, flatpak | | yes | Silverblue/Bazzite immutable |

**Package tiers:**
- **Tier 1 (ALL machines):** Modern CLI tools (eza, bat, fd, ripgrep, etc.), shell (fish, atuin, zoxide), git, neovim, tmux, essential utils
- **Tier 2 (tier >= 2):** Development SDKs (mise, uv, node), build tools (imagemagick, p7zip), AI tools (llm, gemini-cli, opencode), dev utilities (shellcheck, tokei, hyperfine)
- **Tier 3 (tier >= 3):** GUI applications (VS Code, JetBrains, browsers, productivity apps) — installed alongside CLI tools via the same `run_onchange_01` dispatcher

### OS Detection in Templates
Templates use `{{ if eq .chezmoi.os "darwin" }}` for macOS-specific and `{{ else }}` for Linux paths (e.g., Homebrew paths, SSH agent sockets).

### Package Management

Packages are defined once in `.chezmoidata/packages.yaml` and installed via platform-specific package managers:
- **macOS**: Homebrew (via `Brewfile.tmpl`)
- **Arch Linux**: paru (handles both official repos and AUR)
- **Debian/Ubuntu**: apt (native repos only)

The YAML key is the default package name for all package managers. Packages are available on all platforms by default. Only add fields when they differ from defaults:
- `brew_name:`/`arch_name:`/`apt_name:` — override name for a specific manager
- `brew: false`/`arch: false` — exclude from a platform
- `cask: true` — install as Homebrew cask instead of formula

The `run_onchange_01-install-packages.sh` script reads the profile and routes to the appropriate installer:
- macOS: `brew bundle` with `Brewfile.tmpl` (tiers 1-2 formulas + tier 3 casks/MAS)
- Arch: `scripts/install-packages-pacman.sh.tmpl` (tiers 1-3 via paru)
- Debian/Ubuntu: `scripts/install-packages-apt.sh.tmpl` (tiers 1-2)
- Fedora: `scripts/install-packages-dnf.sh.tmpl` (tiers 1-2)
- Linux GUI apps: `scripts/install-packages-flatpak.sh.tmpl` (tier 3, for profiles with `flatpak: true`)
- Silverblue: AppImage downloads for packages with `appimage:` field (tier 3)

**Debian/Ubuntu apt availability:**
The apt install script uses runtime `apt-cache` checks to determine package availability, so it works correctly across different Debian/Ubuntu versions without static exclusion lists. Packages available in Ubuntu 24.04 but missing in Debian Bookworm (e.g., eza, sd, git-delta, gping, yq, hyperfine) will be installed where available and skipped with warnings where not.

### Key Files
- `.chezmoidata/packages.yaml` - Single source of truth for all package definitions across platforms
- `.chezmoidata/profiles.yaml` - Machine profile definitions (tier, pkg managers, is_work, decrypt)
- `Brewfile.tmpl` - Package manifest for Homebrew (macOS, tiers 1-3)
- `scripts/install-packages-pacman.sh.tmpl` - Arch Linux package installer (tiers 1-3 via paru)
- `scripts/install-packages-apt.sh.tmpl` - Debian/Ubuntu package installer (tiers 1-2)
- `scripts/install-packages-dnf.sh.tmpl` - Fedora package installer (tiers 1-2)
- `scripts/install-packages-flatpak.sh.tmpl` - Flatpak installer for tier 3 GUI apps (Linux)
- `run_onchange_01-install-packages.sh.tmpl` - Routes all tiers to correct installer based on profile
- `run_onchange_02-install-fisher.sh` - Installs Fisher and Fish plugins on changes
- `dot_config/fish/conf.d/0_bling.fish` - Shell abbreviations, atuin/zoxide init, CLI tips
- `dot_config/fish/fish_plugins.tmpl` - Fisher plugin manifest (OS-specific)
- `dot_config/git/config.tmpl` - Git config with delta pager, useful aliases

### Philosophy
- All modern CLI tools are abbreviated over old commands (`ls→eza`, `cat→bat`, `rm→trash`, `diff→difft`, `df→duf`, `du→dust`, `ping→gping`, `grep→rg`, `find→fd`, `sed→sd`, `curl→xh`). Since abbreviations expand visibly before running, this forces learning the new syntax.
- Shorthand abbreviations for longer tool names: `lg→lazygit`, `br→broot`
- Shell greeting shows random CLI tips to teach modern tool usage
