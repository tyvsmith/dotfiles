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

Some configs (SSH trusted hosts) are age-encrypted. Decryption is **opt-in** via `--decrypt` flag.

**Requirements:**
- 1Password CLI (`op`) signed in, OR
- Age key at `~/.config/chezmoi/age-key.txt`

**Editing encrypted files locally:**
```bash
# Decrypt for editing (creates decrypted_* files, gitignored)
./scripts/decrypt-secrets.sh

# Edit the decrypted file
vim private_dot_ssh/config.d/decrypted_00-trusted

# Re-encrypt after editing
./scripts/encrypt-secrets.sh
```

## What's Included

### Shell
- **Fish** with [Tide](https://github.com/IlanCosman/tide) prompt
- **Atuin** for shell history sync
- **Zoxide** for smart directory jumping
- **Fisher** plugins: autopair, gitnow, nvm, done, puffer-fish

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
├── install.sh                   # New machine setup script
├── Brewfile.tmpl                # Homebrew packages (templated)
├── .chezmoi.toml.tmpl           # Chezmoi config template
├── .chezmoiignore.tmpl          # Ignore rules (templated)
├── .age-public-key              # Age encryption public key
├── run_before_00-decrypt.sh.tmpl  # Age key setup (if decrypt enabled)
├── run_onchange_01-install-packages.sh  # brew bundle
├── run_onchange_02-install-fisher.sh    # Fisher plugins
├── scripts/
│   ├── encrypt-secrets.sh       # Encrypt decrypted_* files
│   ├── decrypt-secrets.sh       # Decrypt for local editing
│   └── lib/common.sh
├── dot_config/
│   └── fish/
│       ├── conf.d/
│       │   └── 0_bling.fish     # Atuin, zoxide, abbreviations
│       └── fish_plugins.tmpl    # Fisher plugin list
├── dot_gitconfig.tmpl           # Git config (templated)
└── private_dot_ssh/
    ├── config.tmpl              # SSH config
    └── config.d/
        ├── encrypted_00-trusted.age  # Encrypted trusted hosts
        └── decrypted_00-trusted      # Plaintext (gitignored)
```

## Updating

```bash
chezmoi update
```

## Adding New Dotfiles

```bash
chezmoi add ~/.config/some/file
chezmoi cd  # go to source directory
git add -A && git commit -m "Add some/file"
git push
```
