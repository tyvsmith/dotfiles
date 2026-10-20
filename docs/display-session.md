# Game and streaming display profiles

Use hyprmoncfg 1.25.1+ for monitor configuration. Two saved profiles and one streaming template define the contexts:

| Profile | Mode | Color | VRR |
|---|---|---|---|
| desktop | preferred local mode | SDR | fullscreen |
| gaming | preferred local mode | HDR | fullscreen |
| streaming | client width, height and FPS | HDR | off |

The supplied profiles match this LG panel. Edit Desktop and Gaming through hyprmoncfg and add desired changes back to chezmoi. Streaming defaults live in `~/.config/hyprmoncfg/streaming.json`, outside its saved profile library. Keep its generated `hyprmoncfg-monitors.lua` unmanaged; it loads last. Monitor HDR does not force an SDR game to render HDR.

## Lifecycle hooks

- keep Steam launch options as `scb -- %command%`
- apply Gaming before the native game or Gamescope starts; use ScopeBuddy's post hook for cleanup
- set Sunshine preparation Do to `$(HOME)/.local/bin/hypr-display-session stream-start`
- set Sunshine preparation Undo to `$(HOME)/.local/bin/hypr-display-session stream-stop`
- keep the Sunshine launcher detached when ending a stream should leave the game running

`hypr-display-session` stores one game ID and the requested streaming dimensions/FPS in the compositor's runtime directory. A lock serializes hooks. Streaming wins over Gaming; Gaming wins over Desktop. Starting or ending a game during streaming updates only its marker. Every display change uses `hyprmoncfg apply PROFILE --confirm-timeout 0`.

`stream-start` reads `SUNSHINE_CLIENT_WIDTH`, `SUNSHINE_CLIENT_HEIGHT` and `SUNSHINE_CLIENT_FPS`. Explicit arguments are available for testing:

```sh
hypr-display-session stream-start --width 3840 --height 2160 --fps 60
hypr-display-session stream-stop
```

The helper uses `hyprctl` and `jq` to select an advertised mode, including 59.94 Hz for a 60 FPS request. It generates a concrete profile under its runtime directory and supplies that directory to the hyprmoncfg CLI. No generated stream profile enters the saved hardware library. A new stream size reapplies even when the Streaming context is already active. `stream-info` reports requested dimensions/FPS for new ScopeBuddy launches.

Failed starts restore the previous markers. Stops clear their marker even if applying the next profile fails. Sunshine's existing service has best-effort exit hooks for USB stop and display `stream-stop`, covering process failure before application Undo. It is ordered after the monitor daemon so cleanup precedes daemon shutdown. A monitor daemon restart does not clear activity. No subscriber, watcher or automatic retry runs. The reset service runs once per graphical session. Force-killing a game launcher can skip its post hook; use `hypr-display-session reset` to clear both contexts and restore Desktop. `hypr-display-session status` prints the intended profile, not verified monitor state.

Systemd starts the native daemon with the graphical session. A separate `hypr-display-session.service` oneshot resets Desktop after the graphical environment is ready and the daemon starts. It waits up to five seconds for the daemon socket. UWSM imports the compositor identity before reaching the graphical session target. The oneshot remains active until logout, so daemon restarts and configuration reloads preserve activity. The generated monitor configuration persists, so a previous HDR profile may appear briefly during login before the reset runs.

## Limits

- accept advertised monitor resolutions with refresh within 0.5 Hz of client FPS; choose the closest refresh and reject unsupported modes before changing state
- follow Sunshine application lifetime, not each client connection; explicitly end the application before switching TV/phone modes or continuing locally
- retain an already-running game's resolution, frame cap and Gamescope arguments until changed in-game or relaunched
- rely on hyprmoncfg's native hardware matching; hotplug or daemon restart can supersede the selected profile without reapplying activity
- avoid editing monitor previews during a game or stream; failed hooks require manual recovery
- support one game and one Sunshine application at a time

## Review and deploy

Merge the reviewed changes into the configured chezmoi source before applying. Apply while no game or Sunshine application is running. Sunshine's `apps.json` and `sunshine.conf` are tracked directly, including the remaining adaptive Steam launcher. Add later UI changes back to chezmoi before applying. Pairing and credential state stays local. The apply hook reloads unit definitions and re-enables both units under `graphical-session.target`, replacing the daemon's packaged `default.target` enablement. Start a new Hyprland session after deployment. For an intentional reset in the current session, run `hypr-display-session reset`.

The branch removes sticky-HDR initialization from monitors.lua; the old live Sunshine Lua adapter becomes unused. The old Sunshine helper and Lua adapter can be archived once no preparation commands reference them.

Validate physical HDR, actual game presentation, Sunshine Quit App behavior and client modes after deployment. Automated checks exercise the installed daemon with a disposable compositor fixture and ScopeBuddy with fake launch commands; they do not prove physical HDR.

To roll back, restore the previous monitor configuration, ScopeBuddy files and Sunshine helper together. Remove the generated include and stop native hyprmoncfg management before re-enabling sticky-HDR.
