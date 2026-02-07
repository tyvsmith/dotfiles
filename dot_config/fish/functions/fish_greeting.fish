# =============================================================================
# REMOVED - Learn the new syntax directly:
# - grep → use 'rg' (different: rg "pattern" vs grep -r "pattern" .)
# - find → use 'fd' (different: fd "pattern" vs find . -name "pattern")
# - du   → use 'dust' (just run it, no args needed)
# - df   → use 'duf' (just run it, no args needed)
# - ps   → use 'procs' (just run it, no args needed)
# - sed  → use 'sd' (different: sd 'old' 'new' file)
# - curl → use 'xh' (different: xh GET url)
# - top  → use 'btm' (TUI, just run it)
# =============================================================================

# Random modern CLI tips - shows 2 random tips each shell
function fish_greeting
    set -l tips \
        "eza                     list files with color (replaces ls)" \
        "eza -l --icons          list with icons and details" \
        "eza -la                 list all including hidden" \
        "eza --tree              tree view of directory" \
        "eza --tree --level=2    tree with depth limit" \
        "eza -l --git            show git status in listing" \
        "eza --sort=modified     sort by modification time" \
        "bat file.txt            view with syntax highlighting (replaces cat)" \
        "bat -n file.txt         show line numbers only (no decorations)" \
        "bat -l json file        force specific language highlighting" \
        "bat --diff file         show git diff in file" \
        "bat -A file             show non-printable characters" \
        "fd pattern              find files by name (replaces find)" \
        "fd -e txt               find all .txt files" \
        "fd -e txt -x rm         find and delete all .txt files" \
        "fd -H pattern           include hidden files in search" \
        "fd -t d pattern         find only directories" \
        "fd -t f -e py           find only Python files" \
        "fd . -e jpg -x cp {} pics/   copy all jpgs to pics/" \
        "rg pattern              search file contents (replaces grep)" \
        "rg -i pattern           case-insensitive search" \
        "rg -t py 'def '         search only Python files" \
        "rg -l pattern           list only filenames with matches" \
        "rg -c pattern           count matches per file" \
        "rg --json pattern       output as JSON" \
        "rg -F 'literal.string'  literal search (no regex)" \
        "rg -v pattern           invert match (lines NOT matching)" \
        "rg 'pat' -r 'new'       search and replace (preview)" \
        "dust                    visual disk usage (replaces du)" \
        "dust -d 2               disk usage with depth limit" \
        "dust -r                 reverse sort order" \
        "dust -n 10              show only top 10 items" \
        "duf                     disk free space (replaces df)" \
        "duf -only local         show only local filesystems" \
        "procs                   process list with color (replaces ps)" \
        "procs --tree            process tree view" \
        "procs -w keyword        watch processes matching keyword" \
        "procs --sortd cpu       sort by CPU descending" \
        "btm                     system monitor TUI (replaces top/htop)" \
        "btm --basic             minimal mode, less resources" \
        "btm -g                  group processes by name" \
        "sd 'old' 'new' file     replace text in file (replaces sed)" \
        "sd -s 'lit' 'new'       literal string replace (no regex)" \
        "sd -f i 'OLD' 'new'     case-insensitive replace" \
        "sd '(\\d+)' '[$1]'      regex with capture groups" \
        "delta file1 file2       beautiful diff output" \
        "delta --side-by-side    side-by-side diff view" \
        "difft file1 file2       structural diff (replaces diff)" \
        "difft --display inline  inline diff display" \
        "xh GET url              HTTP GET request (replaces curl)" \
        "xh POST url key=val     POST with JSON body" \
        "xh PUT url < file.json  PUT with file body" \
        "xh url header:value     add custom header" \
        "xh -d url               download file" \
        "xh -v url               verbose output with headers" \
        "doggo example.com       DNS lookup (replaces dig)" \
        "doggo example.com MX    query specific record type" \
        "doggo -r 1.1.1.1 host   use specific DNS resolver" \
        "gping google.com        ping with graph (replaces ping)" \
        "gping host1 host2       ping multiple hosts" \
        "z dirname               jump to directory (replaces cd)" \
        "z -                     jump to previous directory" \
        "zi                      interactive directory picker" \
        "broot                   interactive tree explorer" \
        "br -s                   show sizes in tree" \
        "br -h                   show hidden files" \
        "br -g                   show git status" \
        "trash file              safe delete to trash (replaces rm)" \
        "trash-list              show trashed files" \
        "trash-restore           restore trashed files" \
        "trash-empty             empty the trash" \
        "choose 0 2              pick columns 0 and 2 (replaces cut)" \
        "choose -f ':' 0         use : as delimiter" \
        "choose 2:5              select range of columns" \
        "tokei                   count lines of code (replaces cloc)" \
        "tokei -e tests          exclude directory from count" \
        "tokei -t=Rust,Python    only count specific languages" \
        "hyperfine 'cmd'         benchmark a command" \
        "hyperfine 'a' 'b'       compare two commands" \
        "hyperfine -w 3 'cmd'    3 warmup runs before benchmark" \
        "hyperfine --export-markdown results.md 'cmd'" \
        "grex 'foo' 'bar'        generate regex from examples" \
        "grex -r 'test1' 'test2' generate with repetition" \
        "lazygit                 git TUI for staging/commits" \
        "tldr tar                quick examples (replaces man)" \
        "tldr -u                 update tldr cache" \
        "tldr -l                 list all available pages" \
        "atuin search cmd        search shell history" \
        "atuin stats             shell history statistics" \
        "jq '.'                  pretty-print JSON" \
        "jq '.key'               extract key from JSON" \
        "jq '.[] | .name'        extract name from array items" \
        "jq -r '.key'            raw output (no quotes)" \
        "jq 'keys'               get all keys from object" \
        "yq '.'                  pretty-print YAML" \
        "yq '.key' file.yaml     extract key from YAML" \
        "yq -o=json file.yaml    convert YAML to JSON" \
        "yq -i '.key = \"val\"'  edit YAML in place" \
        "chezmoi status          show dotfile changes" \
        "chezmoi diff            diff dotfile changes" \
        "chezmoi apply           apply dotfile changes" \
        "chezmoi add ~/.config/x add file to dotfile management" \
        "chezmoi edit ~/.bashrc  edit managed dotfile" \
        "chezmoi cd              cd to chezmoi source dir" \
        "direnv allow            allow .envrc in current dir" \
        "direnv deny             block .envrc in current dir" \
        "direnv status           show direnv state" \
        "nvim file               modern vim (replaces vim)" \
        "nvim +123 file          open at line 123" \
        "nvim -d file1 file2     diff mode" \
        "nvim -R file            read-only mode" \
        "shellcheck script.sh    lint shell script" \
        "shellcheck -f diff      output as diff for fixing" \
        "tv                      fuzzy finder TUI (television)" \
        "tv --preview            fuzzy find with preview"

    set -l count (count $tips)
    set -l idx1 (random 1 $count)
    set -l idx2 (random 1 $count)

    # Ensure we get two different tips
    while test $idx1 -eq $idx2
        set idx2 (random 1 $count)
    end

    set_color cyan
    echo "💡 Modern CLI tips:"
    set_color normal
    echo "  $tips[$idx1]"
    echo "  $tips[$idx2]"
end
