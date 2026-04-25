function img2jpg-medium --description 'Convert image to 4K JPG (max 2160px wide)'
    set -l img $argv[1]
    set -l extra $argv[2..]
    magick $img $extra -resize '2160x>' -quality 85 -strip (string replace -r '\.[^.]+$' '' $img)-medium.jpg
end
