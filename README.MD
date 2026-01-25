# Ty's Dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io/), using Fish shell.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/tyvsmith/dotfiles/chezmoi-fish/bootstrap.sh | bash
```

This will:
1. Install [Homebrew](https://brew.sh/) (if not present)
2. Install chezmoi
3. Clone this repo and apply dotfiles
4. Install packages from Brewfile
5. Install Fisher and Fish plugins

## Optional Source Directory

By default, chezmoi uses its standard source directory (e.g. `~/.local/share/chezmoi`). You can customize this at init time:

```bash
CHEZMOI_SOURCE_DIR=/path/to/chezmoi/source chezmoi init --apply https://github.com/tyvsmith/dotfiles.git
```

If you run `chezmoi init` interactively, you’ll also be prompted to customize the source directory.

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

If you prefer not to use the bootstrap script:

```bash
# Install chezmoi
brew install chezmoi

# Initialize and apply
chezmoi init --apply https://github.com/tyvsmith/dotfiles.git

# Install packages
brew bundle --file="$(chezmoi source-path)/Brewfile"
```

## Structure

```
dotfiles/
├── bootstrap.sh                 # New machine setup script
├── Brewfile                     # Homebrew packages
├── scripts/
│   ├── run_onchange_01-install-packages.sh
│   ├── run_onchange_02-install-fisher.sh
│   ├── run_onchange_05-macos-defaults.sh.tmpl
│   └── lib/
│       └── common.sh
├── dot_config/
│   └── fish/
│       ├── conf.d/
│       │   ├── bling.fish       # Atuin, zoxide, abbreviations
│       │   ├── paths.fish
│       │   ├── vars.fish.tmpl   # EDITOR, SSH_AUTH_SOCK
│       │   └── dot_gitnow       # Gitnow keybindings
│       └── fish_plugins         # Fisher plugin list
├── dot_gitconfig.tmpl           # Git config (templated)
└── legacy/                      # Old zsh config (archived)
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
