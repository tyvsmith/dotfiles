if status is-interactive
    #Zoxide
    eval "$(zoxide init fish)"
    complete --erase --command __zoxide_z
    complete --command __zoxide_z --no-files --arguments '(__hybrid_zoxide_z_complete)'
    
    #Atuin
    eval "$(atuin init fish)"

    #Set simple hostname for prompt display
    set -gx HOST (hostname -s)
end