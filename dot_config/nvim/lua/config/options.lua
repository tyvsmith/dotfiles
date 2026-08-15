-- Added by omarchy migration 1781587663 ("Enable secure remote Neovim clipboard
-- support"). The provider it loads, lua/config/remote_clipboard.lua, is shipped
-- by the omarchy-nvim package and stays untracked -- omarchy owns that file.
-- Kept here only so chezmoi stops stripping omarchy's line on every apply.
require("config.remote_clipboard").setup()

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
