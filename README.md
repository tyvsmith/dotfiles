# Ty's Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io/), using Fish shell. Targets macOS and Linux (including immutable distros like Bazzite/Fedora Silverblue).

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/main/install.sh | bash
```

Or with options:
```bash
# Specific profile
curl ... | bash -s -- --profile macos-work

# From a specific branch
curl ... | bash -s -- --branch feature-branch

# Seed the age key so encrypted configs decrypt on first apply
curl ... | DOTFILES_AGE_KEY="$(op read op://dev-keys/dotfiles-age-key/key)" bash
# or: --age-key "$(op read ...)"; the env form keeps the key out of process arguments
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
| `--profile <name>` | `DOTFILES_PROFILE` | Machine profile (see below); skips the interactive prompt |
| `--branch <name>` | `DOTFILES_BRANCH` | Git branch for remote install (default `main`) |
| `--age-key <key>` | `DOTFILES_AGE_KEY` | Age secret key, written to `~/.config/chezmoi/age-key.txt` |

## Profiles

Each profile fully specifies a machine setup: category tags, package managers, work mode, decryption, and backups. See `home/.chezmoidata/profiles.yaml` for the source of truth.

| Profile | Tags | Pkg Managers | Devpod | Work | Decrypt | Backup | Description |
|---------|------|--------------|--------|------|---------|--------|-------------|
| `macos-work` | core, core-extra, container, dev, dev-extra, dev-toolchains, experiment, ai, ui, ui-extra | brew | | yes | yes | | Work Mac — full dev setup with corporate config |
| `arch-desktop` | core, core-extra, container, dev, dev-extra, dev-toolchains, experiment, ai, hardware, ui, ui-extra, gaming | pacman, flatpak, appimage | | | yes | yes | Arch Linux desktop — full setup with paru + flatpak |
| `debian-server` | core | apt | | | | | Debian/Ubuntu server — CLI tools only |
| `devpod` | core, dev, ai | brew | yes | yes | | | Work devpod (Debian) — lean CLI + dev tools via Linuxbrew; toolchains come from the image/repo |
| `devpod-slim` | core, dev, ai | mise | yes | yes | | | Work devpod (Debian) — same tools as devpod, as mise-pinned release binaries (no Linuxbrew) |
| `silverblue` | core, core-extra, container, dev, dev-extra, dev-toolchains, experiment, ai, hardware, ui, ui-extra, gaming | brew, rpm-ostree, flatpak, appimage | | | yes | | Fedora Silverblue/Bazzite — immutable desktop |

Package categories behind each tag are described in `AGENTS.md`.

## Encrypted Configs

Some configs (SSH trusted hosts, git identity) are age-encrypted. Decryption is enabled per profile (`decrypt: true` in `profiles.yaml`).

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
- **Fish** with [Starship](https://starship.rs) prompt via fish-fast-starship (config in `.config/starship.toml`)
- **Atuin** for shell history sync
- **Zoxide** for smart directory jumping (`cd` falls through to a zoxide jump when the target is not a directory)
- **Fisher** plugins: done, abbreviation-tips, autopair, replay, sponge, puffer-fish, fzf, fish-fast-starship
- **Omarchy parity**: fish ports of omarchy's bash functions (tmux/herdr dev layouts, rsync watchers, ssh port forwards and auto-reconnect, worktrees, drives) plus `omarchy` tab completion

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
| `rm` | `trash-put` | Safe delete |

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

## Tests

`tests/run.sh` runs every offline suite: the Python tests under `tests/*/` and
the Hyprland Lua checks. It needs `python3`, `chezmoi`, `age`, `jq`, and `lua`,
which CI installs. Suites work in temporary directories and never apply to the
desktop; `python3 tests/chezmoi/test_source_root.py` alone checks worktree
isolation, profile rendering, and the secret helpers with a disposable age key.
`tests/voxtype/run.sh` is separate: it calls the live LLM and skips unless
`~/.config/voxtype/secrets.env` is present.

