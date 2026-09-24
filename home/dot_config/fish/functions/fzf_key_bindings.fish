# No-op stub to prevent the system fzf package's vendor function from
# overriding keybindings (e.g., Ctrl+R). We use patrickf1/fzf.fish instead,
# configured via fzf_configure_bindings in conf.d/zz_03_interactive.fish.
function fzf_key_bindings
end
