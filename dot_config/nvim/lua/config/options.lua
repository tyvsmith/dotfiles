-- Originally added by omarchy migration 1781587663 ("Enable secure remote
-- Neovim clipboard support"), which installs the provider from the omarchy-nvim
-- package and prepends this line.
--
-- Both this line and lua/config/remote_clipboard.lua are tracked here, because
-- .config/nvim/ is NOT gated to omarchy in .chezmoiignore -- it deploys to
-- macOS and servers too, where omarchy-nvim does not exist. Tracking only the
-- require would leave those machines loading a module that is not there.
--
-- The provider is kept byte-identical to omarchy's copy so it stays diffable;
-- if a future omarchy migration ships a newer one, it shows up as a chezmoi
-- diff rather than silently reverting. Off-omarchy it degrades to pure OSC 52
-- (no wl-copy/wl-paste), which is the remote case it exists for anyway.
require("config.remote_clipboard").setup()

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
