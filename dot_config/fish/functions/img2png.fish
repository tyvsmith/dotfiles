function img2png --description 'Convert image to optimized lossless PNG'
    set -l img $argv[1]
    set -l extra $argv[2..]
    magick $img $extra -strip \
        -define png:compression-filter=5 \
        -define png:compression-level=9 \
        -define png:compression-strategy=1 \
        -define png:exclude-chunk=all \
        (string replace -r '\.[^.]+$' '' $img)-optimized.png
end
