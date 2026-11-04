# Display tests

```sh
python3 -m unittest discover -s tests/display-session -v
lua tests/hypr/monitors.lua
```

- check native/Gamescope HDR start and exit paths, failed starts, and local launches with a tablet attached
- check absent and mode-less game configs, single loading, preserved fallback arguments, and native flags without leaking into Gamescope
- check literal AppID declarations select named game files without executing unrelated configs or needing a central map
- check local/streaming preference selection, existing Gamescope reuse, preserved game flags/arguments and absence of display operations in session mode
- exercise all six context/mode combinations through installed ScopeBuddy with isolated command stubs
- check one cached display snapshot, dynamic pixel geometry, fractional refresh, active Xrandr mode selection and missing/ambiguous metadata
- check SDR/HDR stream launches never write monitor rules and local HDR restores on exit
- check virtual fractional scales and updates restricted to the intended monitor property
- check LG-only runtime HDR rules without enabling a disabled monitor

Physical rendering, stream reconnection, and game HDR detection need live validation.
