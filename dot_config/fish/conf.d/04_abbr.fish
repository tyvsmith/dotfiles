    # =============================================================================
    # Modern CLI Tool Abbreviations
    # These EXPAND visibly before running, helping build muscle memory
    # =============================================================================

    # Eza for ls (compatible - same flags work)
    abbr --add ls 'eza'
    abbr --add ll 'eza -l --icons=auto --group-directories-first'
    abbr --add l. 'eza -d .*'
    abbr --add l1 'eza -1'
    abbr --add la 'eza -la --icons=auto --group-directories-first'
    abbr --add lt 'eza --tree --level=2'

    # Bat for cat (mostly compatible)
    abbr --add cat 'bat'

    # Trash for rm (safer delete)
    abbr --add rm 'trash'

    # Difftastic for diff (basic usage compatible)
    abbr --add diff 'difft'
