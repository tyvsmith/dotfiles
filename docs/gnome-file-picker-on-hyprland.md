# GNOME File Picker on Hyprland

The GNOME file picker (`xdg-desktop-portal-gnome`) provides Nautilus-style file dialogs with breadcrumb path navigation, `Space` for quick preview, and proper hidden file toggling. By default it refuses to run outside of a GNOME session, but it can be forced to work on Hyprland with a systemd override.

## Requirements

- `xdg-desktop-portal-gnome` (pacman)
- `gvfs` (pacman) -- needed for Nautilus file browsing within the picker
- `nautilus` (dependency of the portal, likely already installed)

## Configuration

### Portal config

`~/.config/xdg-desktop-portal/hyprland-portals.conf`:

```ini
[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = gnome
```

### Systemd override

`~/.config/systemd/user/xdg-desktop-portal-gnome.service.d/override.conf`:

```ini
[Service]
Environment="XDG_CURRENT_DESKTOP=GNOME"
UnsetEnvironment=GDK_BACKEND
```

The portal checks `XDG_CURRENT_DESKTOP` and `GDK_BACKEND` at startup. Without this override it logs "Non-compatible display server, exposing settings only" and disables the FileChooser interface entirely. The override makes it pass those checks while only affecting the portal service, not the rest of the session.

A warning about `org.gnome.Mutter.ServiceChannel` will appear in logs -- this is harmless. The portal falls back to Hyprland's Wayland compositor for window management.

### Apply changes

```bash
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome
```

## How to undo

1. Revert the portal config to use GTK:

```ini
[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = gtk
```

2. Remove the systemd override:

```bash
rm -rf ~/.config/systemd/user/xdg-desktop-portal-gnome.service.d
```

3. Restart services:

```bash
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal
```

4. Optionally uninstall the GNOME portal:

```bash
sudo pacman -Rns xdg-desktop-portal-gnome
```

The GTK file picker shortcuts (`Ctrl+L` for path entry, `Ctrl+H` for hidden files) will work as before.
