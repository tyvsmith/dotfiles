# Ty's Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io/), using Fish shell. Targets macOS and Linux (including immutable distros like Bazzite/Fedora Silverblue).

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/install.sh | bash
```

Or with options:
```bash
# Non-interactive with auto-detected profile
curl ... | bash -s -- --defaults

# Specific profile
curl ... | bash -s -- --profile macos-work

# From a specific branch
curl ... | bash -s -- --branch feature-branch
```

This will:
1. Install prerequisites (Xcode CLI tools on macOS, build tools on Linux)
2. Install Homebrew (macOS only)
3. Install chezmoi
4. Prompt for profile selection (or use `--profile` flag)
5. Clone and apply dotfiles
6. Install packages based on profile
7. Install Fisher and Fish plugins
8. Configure Tide prompt

### Install Options

| Flag | Environment Variable | Description |
|------|---------------------|-------------|
| `--profile <name>` | `DOTFILES_PROFILE` | Machine profile (see below) |
| `--branch <name>` | `DOTFILES_BRANCH` | Git branch for remote install |
| `--defaults` | - | Use auto-detected profile, no prompts |
| `--quiet`, `-q` | - | Minimal output |

## Profiles

Each profile fully specifies a machine setup: category tags, package managers, work mode, decryption, and backups. See `home/.chezmoidata/profiles.yaml` for the source of truth.

| Profile | Pkg Managers | Work | Decrypt | Backup | Description |
|---------|--------------|------|---------|--------|-------------|
| `macos-work` | brew | yes | yes | | Work Mac — corporate dev + GUI (Time Machine) |
| `arch-desktop` | pacman, flatpak, appimage | | yes | yes | Arch Linux desktop — paru + flatpak |
| `debian-server` | apt | | | | Debian/Ubuntu server — CLI only |
| `devpod` | brew | yes | | | Debian/Ubuntu dev — Homebrew |
| `silverblue` | brew, rpm-ostree, flatpak, appimage | | yes | | Fedora Silverblue/Bazzite — immutable |
| `silverblue` | 3 | Silverblue/Bazzite — Homebrew + flatpak |

**Package tiers:**
- **Tier 1:** Modern CLI tools (eza, bat, fd, ripgrep, etc.), shell (fish, atuin, zoxide), git, neovim, tmux
- **Tier 2:** + Development SDKs (mise, uv, node), AI tools (llm, claude), dev utilities (shellcheck, tokei)
- **Tier 3:** + GUI applications (VS Code, JetBrains, browsers, productivity apps)

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
| `rm` | `gtrash put` | Safe delete |

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

# Set profile via environment
export DOTFILES_PROFILE=arch-desktop

# Initialize and apply
chezmoi init --apply tyvsmith/dotfiles
```

## Structure

```text
dotfiles/
├── .chezmoiroot                  # Contains home
├── home/                        # Chezmoi source state
│   ├── .chezmoi.toml.tmpl        # Profile configuration
│   ├── .chezmoidata/             # Packages and profiles
│   ├── .chezmoitemplates/        # Shared templates
│   ├── .chezmoiignore*           # Target exclusions
│   ├── .chezmoiexternal.toml     # External repositories
│   ├── .age-public-key*         # Encryption recipients
│   ├── run_*                    # Install and configuration scripts
│   ├── dot_config/              # ~/.config
│   ├── dot_local/               # ~/.local
│   ├── dot_agents/              # Shared tool instructions
│   ├── dot_claude/
│   ├── dot_codex/
│   ├── private_dot_ssh/         # SSH configuration
│   └── symlink_dot_devpod.tmpl
├── install.sh                   # Bootstrap entry point
├── scripts/                     # Repository helpers
├── tests/
└── docs/
```

Keep worktrees outside `home/`, for example in `.claude/worktrees/` or
`.worktrees/`. Chezmoi reads nested data before applying ignore rules;
`.chezmoiroot` keeps repository tooling and worktree data outside its source state.
Keep `sourceDir` configured to the repository root; `.chezmoiroot` selects `home/`.

After updating an existing checkout, preview with `chezmoi diff` before applying.
Changed `run_onchange` scripts may run again because their shared-library paths
now point to `../scripts/lib/` from `home/`.


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

## Validate the source layout

Run `python3 tests/chezmoi/test_source_root.py` with `chezmoi`, `age`, and
`age-keygen` installed. Checks cover nested worktree isolation, profile rendering,
shared-library paths, and secret-helper boundaries using a disposable key.
Rendering excludes secrets, backups, and external checkouts; macOS templates
are evaluated on the host OS. No install scripts run.
