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
CHEZMOI_DEV=1 CHEZMOI_GAMING=1 chezmoi init
```

Machine types: `is_development`, `is_work`, `is_gaming`, `is_server`

### OS Detection in Templates
Templates use `{{ if eq .chezmoi.os "darwin" }}` for macOS-specific and `{{ else }}` for Linux paths (e.g., Homebrew paths, SSH agent sockets).

### Key Files
- `Brewfile` - Package manifest for Homebrew (cross-platform)
- `run_once_01-install-packages.sh` - Runs `brew bundle` on init
- `run_once_02-install-fisher.sh` - Installs Fisher and Fish plugins
- `dot_config/fish/conf.d/bling.fish` - Shell abbreviations, atuin/zoxide init, CLI tips
- `dot_config/fish/fish_plugins` - Fisher plugin manifest
- `dot_gitconfig.tmpl` - Git config with delta pager, useful aliases

### Philosophy
- Modern CLI tools are installed but **not aliased over old commands** for tools with different syntax (`rg`, `fd`, `dust`, `sd`, `xh`). Users learn the new syntax directly.
- Tools with compatible syntax are abbreviated: `ls→eza`, `cat→bat`, `rm→trash`, `diff→difft`
- Shell greeting shows random CLI tips to teach modern tool usage
