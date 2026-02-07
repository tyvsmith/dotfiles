# =============================================================================
# Modern CLI Tool Abbreviations
# These EXPAND visibly before running, helping build muscle memory
# =============================================================================

if status is-interactive
    # --- Compatible syntax (flags mostly work the same) ---

    # Eza for ls
    abbr --add ls 'eza'
    abbr --add ll 'eza -l --icons=auto --group-directories-first'
    abbr --add l. 'eza -d .*'
    abbr --add l1 'eza -1'
    abbr --add la 'eza -la --icons=auto --group-directories-first'
    abbr --add lt 'eza --tree --level=2'

    # Bat for cat
    abbr --add cat 'bat'

    # Trash for rm (safer delete)
    abbr --add rm 'trash'

    # Difftastic for diff
    abbr --add diff 'difft'

    # Duf for df (beautiful disk free)
    abbr --add df 'duf'

    # Dust for du (visual disk usage)
    abbr --add du 'dust'

    # Gping for ping (graph visualization)
    abbr --add ping 'gping'

    # --- Different syntax (forces learning the new tool) ---

    # Ripgrep for grep
    abbr --add grep 'rg'

    # fd for find
    abbr --add find 'fd'

    # sd for sed
    abbr --add sed 'sd'

    # xh for curl
    abbr --add curl 'xh'

    # --- Editor (force neovim) ---

    abbr --add vim 'nvim'
    abbr --add vi 'nvim'

    # --- Shorthand for modern tools ---

    # Chezmoi
    abbr --add cz 'chezmoi'

    # Lazygit
    abbr --add lg 'lazygit'

    # Broot
    abbr --add br 'broot'
end
