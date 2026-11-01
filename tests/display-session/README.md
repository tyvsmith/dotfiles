# Display tests

```sh
python3 -m unittest discover -s tests/display-session -v
lua tests/hypr/monitors.lua
```

- check native/Gamescope HDR start and exit paths, failed starts, and local launches with a tablet attached
- check conditional HDR luminance fallback and the read-only Wayland protocol probe
- check virtual fractional scales and preservation of mode, position, and HDR metadata
- check LG-only runtime HDR rules without enabling a disabled monitor

Physical rendering, stream reconnection, and game HDR detection need live validation.
