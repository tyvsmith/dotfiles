# Display-session tests

- run portable helper tests in GitHub Actions on relevant pull requests and main pushes
- cover scale stepping, boundaries, rounded readback, command parsing, and rollback errors

Run the portable checks without Hyprland or hyprmoncfg:

```sh
python3 -m unittest discover -s tests/display-session -p test_scale.py -v
```

Run the full suite locally:

```sh
python3 -m unittest discover -s tests/display-session -v
```

The daemon tests use the installed `hyprmoncfgd` with a disposable compositor and
profile directory. They verify saved scales, preserved profile settings, and
streaming protection without changing the desktop. Daemon, ScopeBuddy, and
systemd checks skip when their dependencies are absent. Physical keypresses,
rendering, and monitor wake behavior require manual validation.
