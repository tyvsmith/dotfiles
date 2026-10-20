# Sunshine controller forwarding

Use **Steam Big Picture (Adaptive + Shield USB)** from any client. USB forwarding is optional: clients absent from the controller map skip it, and a listed client without its controller still streams. Use Moonlight touch controls, keyboard/mouse or its regular gamepad forwarding for those clients.

On the Shield, forward a Steam Controller puck through USB/IP. Runtime needs one user-owned Bash script and usbip-utils. No Python, privileged helper or background USB manager runs.

Edit `~/.config/sunshine-usbip.conf`:

```bash
declare -A controllers=(
    [nvidia-shield-pro.host.tysmith.app]=28de:1304
)
```

Name each paired client using its resolvable hostname in Sunshine. The start hook uses `SUNSHINE_CLIENT_NAME` as the USB/IP server and looks up its controller ID in this map. Keys must match the paired name exactly. Unlisted hosts skip USB discovery. Add another hostname/VID:PID entry for another setup. The Shield's paired name is `nvidia-shield-pro.host.tysmith.app`. Keep its USB/IP server running with permission to export the puck. Listed hosts without a reachable server or matching controller continue streaming without USB forwarding; discovery has a five-second timeout.

## Installation and updates

- install `usbip` through the Linux gaming package definitions
- apply the script, user config and service drop-in through chezmoi
- apply the tracked Sunshine `apps.json` and `sunshine.conf`; they preserve the local Desktop entries and the single adaptive Steam launcher with display and optional USB hooks
- keep pairing certificates, credentials and `sunshine_state.json` local; they are not tracked
- add later Sunshine UI changes back to chezmoi before applying, because the tracked application/config files are authoritative
- run setup after package installation to install `/etc/modules-load.d/sunshine-usbip.conf` and `/etc/sudoers.d/sunshine-usbip`, then load `vhci_hcd` immediately
- validate sudoers before installation; grant passwordless access only to `/usr/bin/usbip attach *` and `/usr/bin/usbip detach *`
- authenticate for initial privileged setup or changes to its definitions; ordinary config/script edits require no authentication

The `run_onchange_52-configure-sunshine-usbip` script tracks the privileged definitions, not the user config or hook. It records their digest after successful installation so reexecution can skip sudo without reading the protected sudoers directory. This records the last installation, not a complete audit of later administrator changes. Remove `~/.local/state/sunshine-usbip/setup.sha256` and rerun setup to reinstall the policy intentionally.

The sudoers rule delegates attach/detach with arbitrary arguments to your account. The script checks attachment ownership to avoid accidental cleanup of another import; this is not a restriction enforced by sudoers. Module loading requires no runtime sudo permission because systemd loads it at boot. A missing module reports an error without blocking streaming.

Restart Sunshine while no application session is active after deploying its preparation commands or drop-in. Normal Quit App uses Sunshine's Undo command. The `app-dev.lizardbyte.app.Sunshine.service.d/cleanup.conf` drop-in adds `ExecStopPost` to the existing Sunshine service so systemd also runs USB stop and display `stream-stop` if Sunshine exits or crashes before Undo. Both are best effort. Ordering keeps the monitor daemon available until Sunshine cleanup finishes when both services stop. A running game retains Gaming; otherwise the display returns to Desktop. It creates no additional service. Repeated stops are harmless. Initial setup reloads the user service definitions; later config edits take effect at the next application launch.

## Lifetime and cleanup

- keep attachment active through network disconnects until Quit App
- end the Sunshine application before switching clients; reconnect does not rerun preparation hooks
- stop only the attachment created by the hook, checking its virtual port, local bus and device number
- retain the original identity for cleanup even when the paired client name or configured device changes
- preserve manually imported matching controllers and refuse ambiguous exports
- continue streaming after USB errors; do not retry automatically after a later network/device drop

The hook uses a lock and ownership files under `$XDG_RUNTIME_DIR/sunshine-usbip`. An interrupted attachment is ambiguous: pending state blocks further operations until the port and state are inspected. It is never automatically adopted. Do not run manual USB/IP operations concurrently with the hook.

Use `sunshine-usbip status` to inspect ownership; it needs no sudo. After a successful Shield stream, test controller inputs in-game and Quit App cleanup. USB enumeration alone does not prove controller behavior.

## Remove

End the application and detach the owned controller. Remove the preparation commands and Sunshine service drop-in. Remove the modules-load file and sudoers rule with sudo approval. Leave shared USB/IP metadata intact.
