#!/usr/bin/env bash
source "${THPM_THEME_ENV:-$HOME/.local/share/thpm/lib/theme-env.sh}"

if [[ ! -d "$HOME/.config/Hermes" ]] && ! command -v hermes >/dev/null 2>&1; then
    skipped "Hermes"
fi

config_dir="$HOME/.config/Hermes"
theme_file="$config_dir/omarchy-theme.json"
mkdir -p "$config_dir"

cat > "$theme_file" <<EOF
{
  "schemaVersion": 1,
  "source": "thpm",
  "theme": {
    "name": "omarchy-current",
    "label": "Omarchy Current",
    "description": "Generated from the active Omarchy theme",
    "colors": {
      "background": "#${primary_background}",
      "foreground": "#${primary_foreground}",
      "card": "#${normal_black}",
      "cardForeground": "#${primary_foreground}",
      "muted": "#${normal_black}",
      "mutedForeground": "#${bright_black}",
      "popover": "#${normal_black}",
      "popoverForeground": "#${primary_foreground}",
      "primary": "#${normal_blue}",
      "primaryForeground": "#${bright_white}",
      "secondary": "#${bright_black}",
      "secondaryForeground": "#${normal_white}",
      "accent": "#${normal_magenta}",
      "accentForeground": "#${bright_white}",
      "border": "#${bright_black}",
      "input": "#${bright_black}",
      "ring": "#${normal_blue}",
      "midground": "#${normal_blue}",
      "midgroundForeground": "#${bright_white}",
      "composerRing": "#${normal_blue}",
      "destructive": "#${normal_red}",
      "destructiveForeground": "#${bright_white}",
      "sidebarBackground": "#${normal_black}",
      "sidebarBorder": "#${bright_black}",
      "userBubble": "#${normal_black}",
      "userBubbleBorder": "#${bright_black}"
    },
    "darkColors": {
      "background": "#${primary_background}",
      "foreground": "#${primary_foreground}",
      "card": "#${normal_black}",
      "cardForeground": "#${primary_foreground}",
      "muted": "#${normal_black}",
      "mutedForeground": "#${bright_black}",
      "popover": "#${normal_black}",
      "popoverForeground": "#${primary_foreground}",
      "primary": "#${normal_blue}",
      "primaryForeground": "#${bright_white}",
      "secondary": "#${bright_black}",
      "secondaryForeground": "#${normal_white}",
      "accent": "#${normal_magenta}",
      "accentForeground": "#${bright_white}",
      "border": "#${bright_black}",
      "input": "#${bright_black}",
      "ring": "#${normal_blue}",
      "midground": "#${normal_blue}",
      "midgroundForeground": "#${bright_white}",
      "composerRing": "#${normal_blue}",
      "destructive": "#${normal_red}",
      "destructiveForeground": "#${bright_white}",
      "sidebarBackground": "#${normal_black}",
      "sidebarBorder": "#${bright_black}",
      "userBubble": "#${normal_black}",
      "userBubbleBorder": "#${bright_black}"
    },
    "terminal": {
      "foreground": "#${primary_foreground}",
      "cursor": "#${cursor_color}",
      "selectionBackground": "#${selection_background}",
      "black": "#${normal_black}",
      "red": "#${normal_red}",
      "green": "#${normal_green}",
      "yellow": "#${normal_yellow}",
      "blue": "#${normal_blue}",
      "magenta": "#${normal_magenta}",
      "cyan": "#${normal_cyan}",
      "white": "#${normal_white}",
      "brightBlack": "#${bright_black}",
      "brightRed": "#${bright_red}",
      "brightGreen": "#${bright_green}",
      "brightYellow": "#${bright_yellow}",
      "brightBlue": "#${bright_blue}",
      "brightMagenta": "#${bright_magenta}",
      "brightCyan": "#${bright_cyan}",
      "brightWhite": "#${bright_white}"
    },
    "darkTerminal": {
      "foreground": "#${primary_foreground}",
      "cursor": "#${cursor_color}",
      "selectionBackground": "#${selection_background}",
      "black": "#${normal_black}",
      "red": "#${normal_red}",
      "green": "#${normal_green}",
      "yellow": "#${normal_yellow}",
      "blue": "#${normal_blue}",
      "magenta": "#${normal_magenta}",
      "cyan": "#${normal_cyan}",
      "white": "#${normal_white}",
      "brightBlack": "#${bright_black}",
      "brightRed": "#${bright_red}",
      "brightGreen": "#${bright_green}",
      "brightYellow": "#${bright_yellow}",
      "brightBlue": "#${bright_blue}",
      "brightMagenta": "#${bright_magenta}",
      "brightCyan": "#${bright_cyan}",
      "brightWhite": "#${bright_white}"
    }
  }
}
EOF

require_restart "Hermes" "Hermes"
success "Hermes theme updated!"
