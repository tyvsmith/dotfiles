# =============================================================================
# Modern CLI Tool Abbreviations
# These EXPAND visibly before running, helping build muscle memory
# _abbr only creates the abbreviation if the target command is installed
# =============================================================================

if status is-interactive
    # --- Compatible syntax (flags mostly work the same) ---

    # Eza for ls
    _abbr ls eza
    _abbr ll 'eza -l --icons=auto --group-directories-first'
    _abbr l. 'eza -d .*'
    _abbr l1 'eza -1'
    _abbr la 'eza -la --icons=auto --group-directories-first'
    _abbr lt 'eza --tree --level=2'

    # Bat for cat
    _abbr cat bat

    # Trash for rm (safer delete)
    _abbr rm trash

    # Difftastic for diff
    _abbr diff difft

    # Duf for df (beautiful disk free)
    _abbr df duf

    # Dust for du (visual disk usage)
    _abbr du dust

    # Gping for ping (graph visualization)
    _abbr ping gping

    # --- Different syntax (forces learning the new tool) ---

    # Ripgrep for grep
    _abbr grep rg

    # fd for find
    _abbr find fd

    # sd for sed
    _abbr sed sd

    # xh for curl
    _abbr curl xh

    # --- Editor (force neovim) ---

    _abbr vim nvim
    _abbr vi nvim

    # --- Shorthand for modern tools ---

    # Chezmoi
    _abbr cz chezmoi
    _abbr cza chezmoi apply

    # Lazygit
    _abbr lg lazygit

    # Broot
    _abbr br broot

    # AI tools
    _abbr c opencode
    _abbr cx 'claude --allow-dangerously-skip-permissions'

    # Common tools
    _abbr d docker
    _abbr p podman
    _abbr t 'tmux attach || tmux new -s Work'

    # fzf file finder + open in editor
    _abbr ff "fzf --preview 'bat --style=numbers --color=always {}'"

    # --- Directory navigation ---
    abbr --add .. 'cd ..'
    abbr --add ... 'cd ../..'
    abbr --add .... 'cd ../../..'

    # --- Container management (distrobox) ---
    _abbr db distrobox
    _abbr dbe 'distrobox enter'
    _abbr dbl 'distrobox list'
    _abbr dbs 'distrobox stop'
    _abbr dbrm 'distrobox rm'
    _abbr dbc 'distrobox create'

    # Zellij
    _abbr zj zellij

    # --- Git ---
    _abbr g git
    _abbr gst git status
    _abbr gco git checkout
    _abbr gbr git branch
    _abbr gp git push
    _abbr gcm 'git commit -m'
    _abbr gcam 'git commit -a -m'
    _abbr gcad 'git commit -a --amend'
    abbr -a --position anywhere --command git st status
    abbr -a --position anywhere --command git co checkout
    abbr -a --position anywhere --command git cm commit
    abbr -a --position anywhere --command git br branch
    abbr -a --position anywhere --command git aa add --all
    abbr -a --position anywhere --command git ap add --patch
    abbr -a --position anywhere --command git pf push --force-with-lease
end
