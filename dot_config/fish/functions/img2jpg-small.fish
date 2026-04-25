function img2jpg-small --description 'Convert image to small JPG (max 1080px wide)'
    set -l img $argv[1]
    set -l extra $argv[2..]
    magick $img $extra -resize '1080x>' -quality 85 -strip (string replace -r '\.[^.]+$' '' $img)-small.jpg
end
