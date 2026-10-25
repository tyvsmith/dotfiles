# Tests

Run offline regression suites from the repository root:

```sh
tests/run.sh
```

- require Python 3, chezmoi, age, jq, and Lua
- discover Python suites under `tests/*/` and run Hyprland Lua checks
- run the same entry point in the shared Tests workflow on pull requests and main pushes
- skip installed-daemon, ScopeBuddy, and systemd checks when their dependencies are absent
- keep fixture state in temporary directories without applying changes to the desktop

Run `tests/voxtype/run.sh` separately for live-model checks. They require local
credentials and network access and are excluded from the offline runner.
