function img2jpg-medium --description 'Convert image to medium JPG (max 1800px wide)'
    set -l img $argv[1]
    set -l extra $argv[2..]
    magick $img $extra -resize '1800x>' -quality 95 -strip (string replace -r '\.[^.]+$' '' $img)-medium.jpg
end
