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

### Machine Type Configuration
The `.chezmoi.toml.tmpl` prompts for machine type on first init, or accepts environment variables:
```bash
DOTFILES_IS_DEV=1 DOTFILES_UI_APPS=1 DOTFILES_IS_WORK=1 DOTFILES_HOMEBREW=1 chezmoi init
```

**Machine type flags:**
- `is_dev` - Development machine (installs SDKs, AI tools, dev utilities)
  - Set to `true` for: personal dev machines, work dev machines, devpods
  - Set to `false` for: homelab servers, infrastructure machines
- `is_work` - Work/corporate machine (affects SSH agent, work-specific configs)
  - Set to `true` for: work machines (uses system SSH agent for ussh compatibility)
  - Set to `false` for: personal machines (uses 1Password SSH agent)
- `install_ui_apps` - Install GUI applications (IDEs, browsers, etc.) via separate `run_onchange_03` script
  - Set to `true` for: machines where you want GUI apps (macOS casks, Arch paru+flatpak, Silverblue flatpak+appimage)
  - Set to `false` for: servers, headless machines, devpods
- `homebrew` - Use Homebrew as primary package manager on Linux (Debian/Ubuntu)
  - Set to `true` for: dev machines where you want current tool versions
  - Set to `false` for: servers, Arch (uses paru), machines where apt is sufficient

**Package tiers:**
- **Tier 1 (ALL machines):** Modern CLI tools (eza, bat, fd, ripgrep, etc.), shell (fish, atuin, zoxide), git, neovim, tmux, essential utils
- **Tier 2 (is_dev=true):** Development SDKs (mise, uv, node), build tools (imagemagick, p7zip), AI tools (llm, gemini-cli, opencode), dev utilities (shellcheck, tokei, hyperfine)
- **Tier 3 (install_ui_apps=true):** GUI applications (VS Code, JetBrains, browsers, productivity apps) — installed via separate `run_onchange_03` script, not bundled with CLI tools

**Example configurations:**
- Personal Mac dev: `is_dev=true`, `is_work=false`, `install_ui_apps=true` (1Password SSH, GUI apps)
- Personal Linux dev: `is_dev=true`, `is_work=false`, `install_ui_apps=false` (1Password SSH, no casks)
- Work Mac dev: `is_dev=true`, `is_work=true`, `install_ui_apps=true` (system SSH for ussh, GUI apps)
- Devpods (Debian): `is_dev=true`, `is_work=true`, `install_ui_apps=false`, `homebrew=true` (CLI + dev tools)
- Homelab server: `is_dev=false`, `is_work=false`, `install_ui_apps=false` (modern CLI only, no 1Password)

### OS Detection in Templates
Templates use `{{ if eq .chezmoi.os "darwin" }}` for macOS-specific and `{{ else }}` for Linux paths (e.g., Homebrew paths, SSH agent sockets).

### Package Management

Packages are defined once in `.chezmoidata/packages.yaml` and installed via platform-specific package managers:
- **macOS**: Homebrew (via `Brewfile.tmpl`)
- **Arch Linux**: paru (handles both official repos and AUR)
- **Debian/Ubuntu**: apt (native repos only)

The YAML key is the default package name for all package managers. Packages are available on all platforms by default. Only add fields when they differ from defaults:
- `brew_name:`/`arch_name:`/`apt_name:` — override name for a specific manager
- `brew: false`/`arch: false`/`apt: false` — exclude from a platform
- `brew_cask: true` — install as Homebrew cask instead of formula

The `run_onchange_01-install-packages.sh` script detects the distro and routes to the appropriate installer:
- macOS: `brew bundle` with `Brewfile.tmpl`
- Arch: `scripts/install-packages-pacman.sh.tmpl`
- Debian: `scripts/install-packages-apt.sh.tmpl`

**Package availability on Debian/Ubuntu:**
Due to Debian's conservative package policies, ~15 modern Rust tools are not available in apt repositories and will be skipped with warnings:
- **Unavailable:** atuin, starship, sd, dust, procs, bottom, difftastic, git-delta, choose, broot, xh, doggo, gping, lazygit, yq, chezmoi (Tier 1)
- **Unavailable:** uv, tokei, hyperfine, grex, llm, gemini-cli, opencode (Tier 2)
- **Available:** fish, zoxide, direnv, neovim, eza, bat, fd, ripgrep, duf, trash-cli, tealdeer, git, git-lfs, gh, fzf, jq, tmux, wget, gnupg, tree

**Binary renames on Debian:**
- `bat` → `batcat` (symlink created automatically in `~/.local/bin`)
- `fd` → `fdfind` (symlink created automatically in `~/.local/bin`)

Missing packages can be installed manually via:
- Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Cargo: `cargo install <package-name>`
- Alternative package sources (PPAs, backports, flatpak)

### Key Files
- `.chezmoidata/packages.yaml` - Single source of truth for all package definitions across platforms
- `Brewfile.tmpl` - Package manifest for Homebrew (macOS, tiers 1-2 only)
- `scripts/install-packages-pacman.sh.tmpl` - Arch Linux package installer (tiers 1-2)
- `scripts/install-packages-apt.sh.tmpl` - Debian/Ubuntu package installer (tiers 1-2)
- `scripts/install-ui-apps.sh.tmpl` - GUI app installer for all platforms (tier 3)
- `run_onchange_01-install-packages.sh.tmpl` - Routes CLI tools to correct installer based on distro
- `run_onchange_03-install-ui-apps.sh.tmpl` - Installs GUI apps when install_ui_apps=true
- `run_onchange_02-install-fisher.sh` - Installs Fisher and Fish plugins on changes
- `dot_config/fish/conf.d/0_bling.fish` - Shell abbreviations, atuin/zoxide init, CLI tips
- `dot_config/fish/fish_plugins.tmpl` - Fisher plugin manifest (OS-specific)
- `dot_config/git/config.tmpl` - Git config with delta pager, useful aliases

### Philosophy
- All modern CLI tools are abbreviated over old commands (`ls→eza`, `cat→bat`, `rm→trash`, `diff→difft`, `df→duf`, `du→dust`, `ping→gping`, `grep→rg`, `find→fd`, `sed→sd`, `curl→xh`). Since abbreviations expand visibly before running, this forces learning the new syntax.
- Shorthand abbreviations for longer tool names: `lg→lazygit`, `br→broot`
- Shell greeting shows random CLI tips to teach modern tool usage
