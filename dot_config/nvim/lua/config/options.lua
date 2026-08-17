-- Remote clipboard provider from omarchy migration 1781587663 (omarchy-nvim).
-- Tracked rather than left to the migration: .config/nvim also deploys to macOS
-- and servers, where omarchy-nvim is absent and this degrades to pure OSC 52.
require("config.remote_clipboard").setup()

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
