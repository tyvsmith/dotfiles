function n --wraps nvim --description 'nvim, defaults to current dir'
    if test (count $argv) -eq 0
        command nvim .
    else
        command nvim $argv
    end
end
