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

# Install packages from Brewfile
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
DOTFILES_IS_DEV=1 DOTFILES_UI_APPS=1 DOTFILES_IS_WORK=1 chezmoi init
```

**Machine type flags:**
- `is_dev` - Development machine (installs SDKs, AI tools, dev utilities)
  - Set to `true` for: personal dev machines, work dev machines, devpods
  - Set to `false` for: homelab servers, infrastructure machines
- `is_work` - Work/corporate machine (affects SSH agent, work-specific configs)
  - Set to `true` for: work machines (uses system SSH agent for ussh compatibility)
  - Set to `false` for: personal machines (uses 1Password SSH agent)
- `install_ui_apps` - Install GUI applications (IDEs, browsers, etc.) - macOS only
  - Set to `true` for: machines where you want GUI apps
  - Set to `false` for: servers, headless machines, Linux (uses native package manager for GUI)

**Package tiers:**
- **Tier 1 (ALL machines):** Modern CLI tools (eza, bat, fd, ripgrep, etc.), shell (fish, atuin, zoxide), git, neovim, tmux, essential utils
- **Tier 2 (is_dev=true):** Development SDKs (sdkman, uv, node), build tools (imagemagick, p7zip), AI tools (llm, gemini-cli, opencode), dev utilities (shellcheck, tokei, hyperfine)
- **Tier 3 (macOS + install_ui_apps=true):** GUI applications (VS Code, JetBrains, browsers, productivity apps)

**Example configurations:**
- Personal Mac dev: `is_dev=true`, `is_work=false`, `install_ui_apps=true` (1Password SSH, GUI apps)
- Personal Linux dev: `is_dev=true`, `is_work=false`, `install_ui_apps=false` (1Password SSH, no casks)
- Work Mac dev: `is_dev=true`, `is_work=true`, `install_ui_apps=true` (system SSH for ussh, GUI apps)
- Devpods (Debian): `is_dev=true`, `is_work=true`, `install_ui_apps=false` (CLI + dev tools)
- Homelab server: `is_dev=false`, `is_work=false`, `install_ui_apps=false` (modern CLI only, no 1Password)

### OS Detection in Templates
Templates use `{{ if eq .chezmoi.os "darwin" }}` for macOS-specific and `{{ else }}` for Linux paths (e.g., Homebrew paths, SSH agent sockets).

### Key Files
- `Brewfile.tmpl` - Package manifest for Homebrew (cross-platform, machine-type aware)
- `run_onchange_01-install-packages.sh` - Runs `brew bundle` on Brewfile changes
- `run_onchange_02-install-fisher.sh` - Installs Fisher and Fish plugins on changes
- `dot_config/fish/conf.d/0_bling.fish` - Shell abbreviations, atuin/zoxide init, CLI tips
- `dot_config/fish/fish_plugins.tmpl` - Fisher plugin manifest (OS-specific)
- `dot_gitconfig.tmpl` - Git config with delta pager, useful aliases

### Philosophy
- All modern CLI tools are abbreviated over old commands (`ls→eza`, `cat→bat`, `rm→trash`, `diff→difft`, `df→duf`, `du→dust`, `ping→gping`, `grep→rg`, `find→fd`, `sed→sd`, `curl→xh`). Since abbreviations expand visibly before running, this forces learning the new syntax.
- Shorthand abbreviations for longer tool names: `lg→lazygit`, `br→broot`
- Shell greeting shows random CLI tips to teach modern tool usage
