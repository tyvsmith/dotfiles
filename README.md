# Ty's Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io/), using Fish shell. Targets macOS and Linux (including immutable distros like Bazzite/Fedora Silverblue).

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/install.sh | bash
```

Or with options:
```bash
# Non-interactive with defaults (dev machine, GUI apps on macOS, no decryption)
curl ... | bash -s -- --defaults

# Specific configuration
curl ... | bash -s -- --dev --no-ui-apps --quiet

# From a specific branch
curl ... | bash -s -- --branch feature-branch
```

This will:
1. Install prerequisites (Xcode CLI tools on macOS, build tools on Linux)
2. Install [Homebrew](https://brew.sh/)
3. Install chezmoi
4. Prompt for machine configuration (or use flags/env vars)
5. Clone and apply dotfiles
6. Install packages from Brewfile
7. Install Fisher and Fish plugins
8. Configure Tide prompt

### Install Options

| Flag | Environment Variable | Description |
|------|---------------------|-------------|
| `--dev` / `--no-dev` | `DOTFILES_IS_DEV` | Development machine (SDKs, AI tools) |
| `--ui-apps` / `--no-ui-apps` | `DOTFILES_UI_APPS` | GUI apps (macOS only) |
| `--decrypt` / `--no-decrypt` | `DOTFILES_DECRYPT` | Enable encrypted config decryption |
| `--branch <name>` | `DOTFILES_BRANCH` | Git branch for remote install |
| `--defaults` | - | Use defaults, no prompts |
| `--quiet`, `-q` | - | Minimal output |

## Machine Types

**Package tiers:**
- **Tier 1 (ALL machines):** Modern CLI tools (eza, bat, fd, ripgrep, etc.), shell (fish, atuin, zoxide), git, neovim, tmux
- **Tier 2 (is_dev=true):** Development SDKs (sdkman, uv, node), AI tools (llm, claude), dev utilities (shellcheck, tokei)
- **Tier 3 (macOS + install_ui_apps=true):** GUI applications (VS Code, JetBrains, browsers)

**Example configurations:**
| Machine | is_dev | install_ui_apps |
|---------|--------|-----------------|
| Personal Linux dev | true | false |
| Work Mac | true | true |
| Homelab server | false | false |

## Encrypted Configs

Some configs (SSH trusted hosts, git identity) are age-encrypted. Decryption is **opt-in** via `--decrypt` flag.

**Requirements:**
- 1Password CLI (`op`) signed in, OR
- Age key at `~/.config/chezmoi/age-key.txt`

### Editing Encrypted Files

**Recommended: Use chezmoi directly**
```bash
# Edit encrypted file (chezmoi decrypts, opens editor, re-encrypts on save)
chezmoi edit ~/path/to/file

# Examples:
chezmoi edit ~/.gitconfig.local
chezmoi edit ~/.ssh/config.d/00-trusted
```

**Alternative: Manual decrypt/encrypt scripts**
```bash
# Decrypt all encrypted files for editing (creates decrypted_* files, gitignored)
./scripts/decrypt-secrets.sh

# Edit the decrypted file
vim private_dot_ssh/config.d/decrypted_00-trusted

# Re-encrypt after editing
./scripts/encrypt-secrets.sh
```

### Adding New Encrypted Files

```bash
# Add a file with encryption
chezmoi add --encrypt ~/.config/sensitive/file.conf

# The file will be stored as encrypted_<name>.age in the source
```

## What's Included

### Shell
- **Fish** with [Tide](https://github.com/IlanCosman/tide) prompt (config tracked)
- **Atuin** for shell history sync
- **Zoxide** for smart directory jumping
- **Fisher** plugins: autopair, gitnow, nvm, done, puffer-fish, fzf, sponge, bass, abbreviation-tips

### Modern CLI Tools
| Instead of | Use | Notes |
|------------|-----|-------|
| `ls` | `eza` | Icons, git integration |
| `cat` | `bat` | Syntax highlighting |
| `find` | `fd` | Simpler, faster |
| `grep` | `rg` | ripgrep |
| `diff` | `delta` / `difft` | Beautiful diffs |
| `du` | `dust` | Visual disk usage |
| `ps` | `procs` | Colored, searchable |
| `top` | `btm` | System monitor TUI |
| `rm` | `trash` | Safe delete |

### Git
- Delta as pager (side-by-side diffs)
- Useful aliases: `git co`, `git ci`, `git st`, `git brs` (fzf branch picker)
- Cross-platform config (macOS/Linux)
- Encrypted local identity (name/email)

## Manual Setup

If you prefer not to use the install script:

```bash
# Install chezmoi
brew install chezmoi

# Set configuration via environment
export DOTFILES_IS_DEV=1
export DOTFILES_UI_APPS=0
export DOTFILES_DECRYPT=0

# Initialize and apply
chezmoi init --apply tyvsmith/dotfiles
```

## Structure

```
dotfiles/
├── install.sh                          # New machine setup script
├── Brewfile.tmpl                       # Homebrew packages (templated)
├── .chezmoi.toml.tmpl                  # Chezmoi config template
├── .chezmoiignore.tmpl                 # Ignore rules (templated)
├── .age-public-key                     # Age encryption public key
├── run_before_00-decrypt.sh.tmpl       # Age key setup (if decrypt enabled)
├── run_onchange_01-install-packages.sh.tmpl  # brew bundle
├── run_onchange_02-install-fisher.sh.tmpl    # Fisher plugins
├── run_onchange_03-configure-tide.sh.tmpl    # Tide prompt config
├── encrypted_dot_gitconfig.local.age   # Encrypted git identity
├── scripts/
│   ├── encrypt-secrets.sh              # Encrypt decrypted_* files
│   ├── decrypt-secrets.sh              # Decrypt for local editing
│   └── lib/common.sh                   # Shared shell functions
├── dot_config/
│   ├── fish/
│   │   ├── conf.d/
│   │   │   ├── 0_bling.fish            # Abbreviations, CLI tips
│   │   │   ├── 0_brew.fish.tmpl        # Homebrew PATH setup
│   │   │   ├── 0_paths.fish            # Additional PATH entries
│   │   │   └── 0_vars.fish.tmpl        # Environment variables
│   │   ├── fish_plugins.tmpl           # Fisher plugin list
│   │   └── tide_config.fish            # Tide 'configure --auto' command
│   └── gh/
│       └── private_config.yml          # GitHub CLI config
├── dot_gitconfig.tmpl                  # Git config (templated)
└── private_dot_ssh/
    ├── config.tmpl                     # SSH config
    └── config.d/
        └── encrypted_00-trusted.age    # Encrypted trusted hosts
```

## Updating

```bash
chezmoi update
```

## Adding New Dotfiles

```bash
# Add a regular file
chezmoi add ~/.config/some/file

# Add an encrypted file
chezmoi add --encrypt ~/.config/sensitive/secret.conf

# Go to source directory and commit
chezmoi cd
git add -A && git commit -m "Add some/file"
git push
```

## Updating Tide Prompt Config

To change your Tide prompt configuration:
```bash
# Run the interactive wizard
tide configure

# At the end, press 'p' to print the command
# Copy the output and update:
chezmoi edit ~/.config/fish/tide_config.fish
```
