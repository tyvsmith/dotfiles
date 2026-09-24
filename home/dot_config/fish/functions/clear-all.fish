function clear-all --description 'Clear screen, scrollback, and home cursor'
    printf '\033[2J\033[3J\033[H'
end
