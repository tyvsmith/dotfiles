# =============================================================================
# Extra Environment Variables
# Supplements omarchy's default envs with things it doesn't set
# =============================================================================

# Podman — point Docker-compatible tools (lazydocker, etc.) at podman socket
if [[ -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
  export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
fi
