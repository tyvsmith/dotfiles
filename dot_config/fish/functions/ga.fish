function ga --description 'Create git worktree + branch'
    if test (count $argv) -eq 0
        echo "Usage: ga [branch name]"
        return 1
    end

    set -l branch $argv[1]
    set -l base (basename $PWD)
    set -l path "../$base--$branch"

    git worktree add -b $branch $path
    mise trust $path
    cd $path
end
