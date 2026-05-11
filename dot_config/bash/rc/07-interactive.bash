# =============================================================================
# Interactive Shell Enhancements
# Cursor reset, CLI tips greeting, and other interactive niceties
# Mirrors fish's zz_03_interactive.fish and fish_greeting.fish
# =============================================================================

# --- Cursor reset in tmux ---
# Tmux doesn't restore cursor shape after apps (neovim, opencode, etc.)
# change it. Reset to bar on each prompt, matching fish behavior.
if [[ -n "${TMUX-}" ]]; then
  __reset_cursor() { printf '\e[6 q'; }
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;} __reset_cursor"
fi

# --- CLI tips greeting ---
# Shows 2 random modern CLI tips every 6 hours (mirrors fish_greeting.fish)
__cli_tips_greeting() {
  local stamp_file=~/.cache/bash_greeting_stamp
  local interval=21600 # 6 hours
  local now
  now=$(date +%s)

  if [[ -f "$stamp_file" ]]; then
    local last
    last=$(<"$stamp_file")
    if (( now - last < interval )); then
      return
    fi
  fi

  mkdir -p ~/.cache
  echo "$now" > "$stamp_file"

  local tips=(
    "eza                     list files with color (replaces ls)"
    "eza -l --icons          list with icons and details"
    "eza -la                 list all including hidden"
    "eza --tree              tree view of directory"
    "eza --tree --level=2    tree with depth limit"
    "eza -l --git            show git status in listing"
    "eza --sort=modified     sort by modification time"
    "bat file.txt            view with syntax highlighting (replaces cat)"
    "bat -n file.txt         show line numbers only (no decorations)"
    "bat -l json file        force specific language highlighting"
    "bat --diff file         show git diff in file"
    "bat -A file             show non-printable characters"
    "fd pattern              find files by name (replaces find)"
    "fd -e txt               find all .txt files"
    "fd -e txt -x rm         find and delete all .txt files"
    "fd -H pattern           include hidden files in search"
    "fd -t d pattern         find only directories"
    "fd -t f -e py           find only Python files"
    "rg pattern              search file contents (replaces grep)"
    "rg -i pattern           case-insensitive search"
    "rg -t py 'def '         search only Python files"
    "rg -l pattern           list only filenames with matches"
    "rg -c pattern           count matches per file"
    "rg -F 'literal.string'  literal search (no regex)"
    "rg -v pattern           invert match (lines NOT matching)"
    "dust                    visual disk usage (replaces du)"
    "dust -d 2               disk usage with depth limit"
    "dust -n 10              show only top 10 items"
    "duf                     disk free space (replaces df)"
    "duf -only local         show only local filesystems"
    "procs                   process list with color (replaces ps)"
    "procs --tree            process tree view"
    "btm                     system monitor TUI (replaces top/htop)"
    "sd 'old' 'new' file     replace text in file (replaces sed)"
    "sd -s 'lit' 'new'       literal string replace (no regex)"
    "delta file1 file2       beautiful diff output"
    "difft file1 file2       structural diff (replaces diff)"
    "xh GET url              HTTP GET request (replaces curl)"
    "xh POST url key=val     POST with JSON body"
    "xh -d url               download file"
    "doggo example.com       DNS lookup (replaces dig)"
    "gping google.com        ping with graph (replaces ping)"
    "z dirname               jump to directory (replaces cd)"
    "zi                      interactive directory picker"
    "broot                   interactive tree explorer"
    "trash file              safe delete to trash (replaces rm)"
    "trash-list              show trashed files"
    "trash-restore           restore trashed files"
    "tokei                   count lines of code (replaces cloc)"
    "hyperfine 'cmd'         benchmark a command"
    "hyperfine 'a' 'b'       compare two commands"
    "lazygit                 git TUI for staging/commits"
    "tldr tar                quick examples (replaces man)"
    "atuin search cmd        search shell history"
    "atuin stats             shell history statistics"
    "jq '.'                  pretty-print JSON"
    "jq '.key'               extract key from JSON"
    "jq '.[] | .name'        extract name from array items"
    "yq '.'                  pretty-print YAML"
    "yq -o=json file.yaml    convert YAML to JSON"
    "chezmoi status          show dotfile changes"
    "chezmoi diff            diff dotfile changes"
    "chezmoi apply           apply dotfile changes"
    "chezmoi cd              cd to chezmoi source dir"
    "nvim file               modern vim (replaces vim)"
    "shellcheck script.sh    lint shell script"
    "tv                      fuzzy finder TUI (television)"
  )

  local count=${#tips[@]}
  local idx1=$((RANDOM % count))
  local idx2=$((RANDOM % count))
  while (( idx1 == idx2 )); do
    idx2=$((RANDOM % count))
  done

  printf '\e[36m💡 Modern CLI tips:\e[0m\n'
  echo "  ${tips[$idx1]}"
  echo "  ${tips[$idx2]}"
}

__cli_tips_greeting
