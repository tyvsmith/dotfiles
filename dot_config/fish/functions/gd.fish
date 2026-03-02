function gd --description 'Remove git worktree + branch'
    gum confirm "Remove worktree and branch?"; or return

    set -l worktree (basename $PWD)
    set -l root (string split -f1 -- '--' $worktree)
    set -l branch (string replace -r '^[^-]*--' '' $worktree)

    # Protect against non-worktree directory
    if test $root = $worktree
        echo "Not in a worktree directory (expected name--branch format)"
        return 1
    end

    cd ../$root
    git worktree remove $worktree --force
    git branch -D $branch
end
