function img2jpg-large --description 'Convert image to 6K JPG (max 3160px wide)'
    set -l img $argv[1]
    set -l extra $argv[2..]
    magick $img $extra -resize '3160x>' -quality 85 -strip (string replace -r '\.[^.]+$' '' $img)-large.jpg
end
