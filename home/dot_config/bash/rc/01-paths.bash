export PATH=$HOME/.local/share/overrides/bin:$PATH:$HOME/.local/bin

# mise-managed packages (devpod-slim): shims make the pinned tools reachable
# without `mise activate`. The drop-in only exists on mise profiles.
if [[ -f $HOME/.config/mise/conf.d/20-packages.toml ]]; then
  export PATH=$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH
fi
