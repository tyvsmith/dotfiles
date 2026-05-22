function open --description 'Open file with the platform-native opener'
    switch (uname)
        case Darwin
            command open $argv
        case '*'
            xdg-open $argv >/dev/null 2>&1 &
            disown
    end
end
