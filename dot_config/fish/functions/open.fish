function open --description 'Open file with xdg-open in background'
    xdg-open $argv >/dev/null 2>&1 &
    disown
end
