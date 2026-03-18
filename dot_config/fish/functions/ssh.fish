function ssh --wraps=ssh --description 'SSH with SHELL override to avoid fish startup in Match exec'
    SHELL=/bin/sh command ssh $argv
end
