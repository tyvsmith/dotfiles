# Launch policy prototype

Applied locally for evaluation. Keep explicit launch controls:

```sh
HYPR_WORKSPACE=6 HYPR_FULLSCREEN=1 HYPR_HDR=1 HYPR_DND=1 scb -- command
```

- read launch controls through `hypr/launch_options.lua`; keep autostart identity and scope fallback there too
- apply workspace/fullscreen once through `placement.lua`; preserve later manual changes
- register HDR outputs in `monitors.lua` and managed apps in `windows.lua` through `launch_policy.lua`
- start placement, HDR, and DND once through `launch_policy.setup()` at the end of `hyprland.lua`
- keep HDR while a local ScopeBuddy launch lives, including on another workspace
- keep the existing pre-launch wait so the game sees HDR before probing display capabilities
- release only the exiting launch; restore SDR after all local demand ends
- leave stream HDR to Punktfunk; export `HYPR_HDR=0` for streamed launches

## Focus-sensitive DND

- default local ScopeBuddy launches to `HYPR_DND=1`; use `HYPR_DND=0` to opt out
- force `HYPR_DND=0` for streamed launches and exclude `PF-*` outputs
- enable Omarchy DND while the focused opted-in window is fullscreen or matches its monitor's logical bounds within two pixels
- disable DND on focus loss, workspace changes, resize to a smaller window, or exit
- use focus events and a 250 ms geometry fallback in `dnd.lua`, sending IPC only when the desired state changes
- save no prior DND value; this policy owns DND transitions and does not preserve manual DND
- keep Omarchy's normal DND exceptions, including verification codes

## Lifetime

The pre-hook registers ScopeBuddy's PID and process start time. A small file in
the current Hyprland runtime directory preserves those identities across config
reloads, including before the first game window appears. Dead processes, zombies,
and reused PIDs lose ownership. ScopeBuddy normally waits for its game; a game
that detaches from the launcher needs separate lifetime validation.

The tracker reconciles on config reload, monitor addition, and window events.
A one-second timer covers DPMS wake, missed cleanup, and actual preset drift.
`monitors.lua` registers the outputs managed by `hdr.lua`, currently `DP-1`.
The module applies each registered baseline and owns subsequent HDR updates.
Runtime updates change only `cm`; geometry stays in the existing monitor rule.
No wildcard or brand-specific logic lives in the tracker.

ScopeBuddy calls `launch_policy.hdr.acquire`, `ready`, and `release`.

The pre-launch command requests HDR on every registered, connected, awake output
and waits for those outputs to report HDR. Sleeping or disconnected outputs keep
their demand until they return. Unregistered outputs are never changed, including
Punktfunk displays; no name-prefix exclusion is needed in the tracker.
Streamed launches still do not register local HDR demand. A local launch can keep
its registered displays in HDR while a stream exists.

An unwrapped window carrying `HYPR_HDR=1` also requests HDR while mapped to
a registered output. This fallback has window lifetime only; ScopeBuddy registration is what
bridges loading screens and window replacement. Shared app processes and
environment rewriting remain limitations of direct environment matching.

## Review boundaries

- keep SDR as the no-demand baseline; manual HDR changes are not a separate override in this prototype
- keep registered output at 10-bit in SDR and HDR, with default forced 8-bit capture
- omit named profiles and structured environment blobs until a concrete caller needs them
- verify an actual native/Gamescope game and a concurrent Punktfunk stream before adopting
- distinguish preset recovery from a driver losing HDR signaling while reporting `hdr`

Applied to the live Hyprland and ScopeBuddy configuration. Verified the real
pre-launch hook, config reload recovery, DPMS sleep/wake, recovery from an SDR
reset, overlapping ownership, and dead-owner cleanup. No game was launched for
these checks; Punktfunk coexistence has only offline coverage. All test registrations were removed. Output depth was subsequently restored to
continuous 10-bit to match the prior sticky-HDR configuration.

Run process-lifetime checks from the host PID namespace. A sandbox PID can name
an unrelated process from the compositor's perspective.
