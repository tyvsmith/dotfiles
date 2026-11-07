function __ssh_disarm --description 'Disarm mouse tracking, focus reporting, alt screen; show cursor'
    # Mouse tracking (1000/1002/1003, 1006 encoding), focus reporting (1004),
    # the alternate screen (1049), and the cursor again.
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h'
end
