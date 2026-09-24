function compress --description 'Create .tar.gz archive'
    tar -czf (string replace -r '/$' '' $argv[1]).tar.gz (string replace -r '/$' '' $argv[1])
end
