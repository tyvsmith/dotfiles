function img2jpg --description 'Convert image to high-quality JPG'
    set -l img $argv[1]
    set -l extra $argv[2..]
    magick $img $extra -quality 95 -strip (string replace -r '\.[^.]+$' '' $img)-converted.jpg
end
