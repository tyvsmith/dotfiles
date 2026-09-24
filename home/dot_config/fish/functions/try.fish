function try --description 'Ephemeral workspace manager (lazy init)'
    functions --erase try
    SHELL=fish command try init ~/Work/tries | source
    try $argv
end
