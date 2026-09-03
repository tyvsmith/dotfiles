# OBS Virtual Camera Filter Gate Design

## Objective

Keep OBS near its idle CPU usage when the virtual camera is stopped while ensuring the configured background-removal filter is enabled whenever the virtual camera is running. The current Program scene may remain `Idle`; the virtual camera continues to target the dedicated `Virtual Camera` scene.

## Context

`obs-backgroundremoval` 1.4.1 implements “Stop filter when source is inactive” using OBS main-view activation callbacks. A scene selected as the dedicated virtual-camera output is rendered without becoming active in the main Program view. Consequently, selecting `Idle` deactivates the filter even while the virtual camera renders the `Virtual Camera` scene.

The script replaces that lifecycle decision with OBS virtual-camera start and stop events. The plugin option “Stop filter when source is inactive” must be unchecked so it does not conflict with the script.

## User Interface

The script exposes two settings in OBS’s Scripts window:

- **Source**: a dropdown containing the current scene collection’s sources.
- **Filter**: a dropdown populated with the filters belonging to the selected source.

Changing either setting immediately synchronizes the selected filter with the current virtual-camera state. The initial intended selections are `Video Capture Device (V4L2)` and `Background Removal`, but names are not hard-coded.

## Lifecycle

The controller has one operation: resolve the selected source and filter, then set the filter’s OBS enabled state.

- On script load, capture the target filter’s original enabled state and synchronize it to whether the virtual camera is currently active.
- On `OBS_FRONTEND_EVENT_VIRTUALCAM_STARTED`, enable the filter.
- On `OBS_FRONTEND_EVENT_VIRTUALCAM_STOPPED`, disable the filter.
- On a relevant settings change, restore the previous target to its original state, capture the new target’s state, and synchronize the new target.
- On script unload, restore the current target’s original enabled state.
- On scene-collection changes, refresh target resolution and synchronize when the configured target exists.

The script responds to OBS’s virtual-camera Start/Stop state. It does not attempt to detect whether another application currently has the Linux virtual-camera device open.

## Failure Handling

If the source or filter cannot be resolved, the script performs no mutation and writes a concise warning to the OBS script log. Repeated synchronization for the same missing target should not flood the log. References acquired from OBS are released after use.

The script does not modify plugin-specific settings. The user must uncheck “Stop filter when source is inactive” once in the Background Removal filter UI.

## Testing

A standalone Lua test harness supplies the minimal OBS API surface needed by the script. Tests cover:

1. Script load disables an initially enabled filter when Virtual Camera is stopped.
2. Virtual Camera start and stop events enable and disable the filter.
3. Script unload restores the original enabled state.
4. A missing source or filter produces no state mutation.
5. Changing the configured target restores the old filter and synchronizes the new filter.
6. Source and filter dropdowns contain the available OBS objects.

The test runner will fail on assertion errors and will be usable without launching the OBS GUI.
