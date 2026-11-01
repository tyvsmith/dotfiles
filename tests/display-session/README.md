# Display tests

```sh
python3 -m unittest discover -s tests/display-session -v
lua tests/hypr/monitors.lua
```

- check native/Gamescope HDR start and exit paths, failed starts, mode switches, and local launches with a tablet attached
- check conditional HDR luminance fallback and parsing of standard `wayland-info` output
- check virtual fractional scales and updates restricted to the intended monitor property
- check LG-only runtime HDR rules without enabling a disabled monitor

Physical rendering, stream reconnection, and game HDR detection need live validation.
