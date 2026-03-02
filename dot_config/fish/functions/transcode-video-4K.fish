function transcode-video-4K --description 'Transcode video to optimized 4K MP4'
    ffmpeg -i $argv[1] -c:v libx265 -preset slow -crf 24 -c:a aac -b:a 192k (string replace -r '\.[^.]+$' '' $argv[1])-optimized.mp4
end
