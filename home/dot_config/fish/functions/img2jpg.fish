function img2jpg --description 'Convert an image to JPG: img2jpg FILE [max-width] [magick args...]'
    set -l img $argv[1]
    set -l resize
    if string match -qr '^[0-9]+$' -- "$argv[2]"
        set resize -resize "$argv[2]x>"
        set -e argv[2]
    end
    magick $img $argv[2..] $resize -quality 85 -strip (string replace -r '\.[^.]+$' '' $img)-converted.jpg
end
