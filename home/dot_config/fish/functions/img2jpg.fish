function img2jpg --description 'Convert images to high-quality JPG: img2jpg [small|medium|large|<width>] FILE...'
    # Presets are max widths; images narrower than the preset are left as is.
    set -l resize
    set -l suffix converted
    switch "$argv[1]"
        case small
            set resize 1080
        case medium
            set resize 2160
        case large
            set resize 3160
        case '*'
            if string match -qr '^[0-9]+$' -- "$argv[1]"
                set resize $argv[1]
            end
    end
    if set -q resize[1]
        set suffix $argv[1]
        set -e argv[1]
    end

    if not set -q argv[1]
        echo 'usage: img2jpg [small|medium|large|<width>] FILE...' >&2
        return 2
    end

    set -l opts -quality 85 -strip
    if set -q resize[1]
        set -p opts -resize "$resize"'x>'
    end

    for img in $argv
        magick $img $opts (string replace -r '\.[^.]+$' '' $img)-$suffix.jpg
    end
end
