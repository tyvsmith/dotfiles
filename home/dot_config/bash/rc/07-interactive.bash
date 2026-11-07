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
# Shows 2 random modern CLI tips every 6 hours (mirrors fish_greeting.fish).
# The tip list is shared with fish: ~/.config/shell/cli-tips.txt
__cli_tips_greeting() {
  local tips_file=~/.config/shell/cli-tips.txt
  [[ -r "$tips_file" ]] || return 0

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

  # read loop, not mapfile: macOS /bin/bash is 3.2
  local tips=() line
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    tips+=("$line")
  done < "$tips_file"

  local count=${#tips[@]}
  (( count >= 2 )) || return 0
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
