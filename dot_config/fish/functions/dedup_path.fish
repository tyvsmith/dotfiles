function dedup_path --description 'Remove duplicate entries from PATH'
    set -l seen
    set -l clean
    for p in $PATH
        if not contains $p $seen
            set -a seen $p
            set -a clean $p
        end
    end
    set -gx PATH $clean
end
