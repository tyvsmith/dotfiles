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
- **macOS**: Homebrew formulas + casks
- **Arch Linux**: paru (handles both official repos and AUR)
- **Debian/Ubuntu**: apt (native repos only)
- **Fedora**: dnf
- **Linux GUI**: Flatpak (Flathub) or AppImage (GitHub releases)

The YAML key is the default package name for all package managers. Manager fields are **tri-state**:
- absent → available, use YAML key as package name
- string → available, use string as package name (e.g., `arch: python-llm`)
- `false` → excluded from this manager (e.g., `brew: false`)

Other package fields:
- `cask: true` — Homebrew cask (macOS-only, cascades to next manager on Linux)
- `tap:` — Homebrew tap required before install
- `flatpak:` — Flatpak app ID
- `appimage:` — GitHub repo (`owner/name`) for AppImage download

Cascade order: `brew → cask → pacman → apt → dnf → flatpak → appimage`. Each package goes to the first enabled manager that can handle it, determined at template time by `.chezmoitemplates/cascade-filter`. Each manager has its own `run_onchange_*` script with a profile guard that renders to `exit 0` when the manager is not enabled.

**Debian/Ubuntu apt availability:**
The apt install script uses runtime `apt-cache` checks to determine package availability, so it works correctly across different Debian/Ubuntu versions without static exclusion lists. Packages available in Ubuntu 24.04 but missing in Debian Bookworm (e.g., eza, sd, git-delta, gping, yq, hyperfine) will be installed where available and skipped with warnings where not.

### Key Files
- `.chezmoidata/packages.yaml` - Single source of truth for all package definitions across platforms
- `.chezmoidata/profiles.yaml` - Machine profile definitions (tier, pkg managers, is_work, decrypt)
- `.chezmoitemplates/cascade-filter` - Shared cascade logic for package manager selection
- `run_onchange_01-install-packages-homebrew.sh.tmpl` - Homebrew formulas (+ Homebrew install on Linux)
- `run_onchange_02-install-packages-cask.sh.tmpl` - Homebrew casks (macOS only)
- `run_onchange_03-install-packages-pacman.sh.tmpl` - Arch Linux (paru, tiers 1-3)
- `run_onchange_04-install-packages-apt.sh.tmpl` - Debian/Ubuntu (apt, tiers 1-2)
- `run_onchange_05-install-packages-dnf.sh.tmpl` - Fedora (dnf, tiers 1-2)
- `run_onchange_06-install-packages-flatpak.sh.tmpl` - Flatpak GUI apps (Linux, tier 3)
- `run_onchange_07-install-packages-appimage.sh.tmpl` - AppImage downloads (Linux, last resort)
- `run_onchange_08-install-fisher.sh.tmpl` - Installs Fisher and Fish plugins on changes
- `dot_config/fish/conf.d/0_bling.fish` - Shell abbreviations, atuin/zoxide init, CLI tips
- `dot_config/fish/fish_plugins.tmpl` - Fisher plugin manifest (OS-specific)
- `dot_config/git/config.tmpl` - Git config with delta pager, useful aliases

### Philosophy
- All modern CLI tools are abbreviated over old commands (`ls→eza`, `cat→bat`, `rm→trash`, `diff→difft`, `df→duf`, `du→dust`, `ping→gping`, `grep→rg`, `find→fd`, `sed→sd`, `curl→xh`). Since abbreviations expand visibly before running, this forces learning the new syntax.
- Shorthand abbreviations for longer tool names: `lg→lazygit`, `br→broot`
- Shell greeting shows random CLI tips to teach modern tool usage
