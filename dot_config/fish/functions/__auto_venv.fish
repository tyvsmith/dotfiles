function __auto_venv --on-variable PWD --description 'Auto-activate the nearest Python .venv on cd'
    # Auto-activate Python virtualenvs on `cd` for any repo that has a .venv —
    # including uv projects: mise's python.uv_venv_auto only covers projects with
    # mise-managed python (intentionally not a global tool), so this function
    # owns plain-.venv activation. Activates the nearest ancestor .venv,
    # deactivates on leaving its tree, and never touches a venv we didn't activate
    # (manual / mise) — we only ever deactivate the one we started (__auto_venv_dir).
    #
    # Autoloaded: zz_03_interactive.fish calls __auto_venv once, which loads this
    # file (registering the --on-variable PWD handler) and activates the start dir.
    set -l found
    set -l dir $PWD
    while true
        if test -e "$dir/.venv/bin/activate.fish"
            set found "$dir/.venv"
            break
        end
        test "$dir" = / ; and break
        set dir (path dirname $dir)
    end

    if test -n "$found"
        test "$VIRTUAL_ENV" = "$found"; and return # already active
        if test -z "$VIRTUAL_ENV"; or set -q __auto_venv_dir
            functions -q deactivate; and deactivate # swap out our previous one
            source "$found/bin/activate.fish"
            set -g __auto_venv_dir "$found"
        end
    else if set -q __auto_venv_dir
        functions -q deactivate; and deactivate
        set -e __auto_venv_dir
    end
end
