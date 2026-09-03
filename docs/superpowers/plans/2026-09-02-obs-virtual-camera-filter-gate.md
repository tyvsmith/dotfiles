# OBS Virtual Camera Filter Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable OBS Lua script that enables one selected source filter while Virtual Camera is running and disables it while Virtual Camera is stopped.

**Architecture:** A single OBS Lua script owns the selected filter’s enabled state and reacts to frontend Virtual Camera events. A standalone Lua harness supplies a deterministic fake `obslua` API so lifecycle, restoration, missing-target, configuration-change, and dropdown behavior can be tested without launching OBS.

**Tech Stack:** OBS Studio Lua scripting API, Lua 5.5, Bash test runner, chezmoi source-state naming.

---

## File Structure

- Create `dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua`: OBS-facing controller, properties UI, target resolution, event handling, and state restoration.
- Create `tests/obs-virtual-camera-filter-gate/test.lua`: standalone behavioral harness with a minimal fake OBS API.
- Create `tests/obs-virtual-camera-filter-gate/run.sh`: syntax-check and test entrypoint.

### Task 1: Add the failing lifecycle harness

**Files:**
- Create: `tests/obs-virtual-camera-filter-gate/test.lua`
- Create: `tests/obs-virtual-camera-filter-gate/run.sh`
- Test: `tests/obs-virtual-camera-filter-gate/test.lua`

- [ ] **Step 1: Write the failing test harness**

Create a fake OBS environment that loads the production script in an isolated Lua environment. Its fake API must provide source/filter lookup and release, filter enable state, Virtual Camera state and events, string settings, logging, source/filter enumeration, and list properties. Define assertions and these cases:

```lua
test("load gates the filter and unload restores it", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Camera", "Background Removal", true)
    h:load({ source_name = "Camera", filter_name = "Background Removal" })
    assert_equal(false, h:filter_enabled("Camera", "Background Removal"))
    h:event(h.obs.OBS_FRONTEND_EVENT_FINISHED_LOADING, false)
    h:unload()
    assert_equal(true, h:filter_enabled("Camera", "Background Removal"))
end)

test("virtual camera events control the filter", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Camera", "Background Removal", true)
    h:load({ source_name = "Camera", filter_name = "Background Removal" })
    h:event(h.obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STARTED, true)
    assert_equal(true, h:filter_enabled("Camera", "Background Removal"))
    h:event(h.obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STOPPED, false)
    assert_equal(false, h:filter_enabled("Camera", "Background Removal"))
end)

test("missing targets do not mutate filters or flood warnings", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Other", "Other Filter", true)
    h:load({ source_name = "Missing", filter_name = "Background Removal" })
    h:event(h.obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STOPPED, false)
    assert_equal(true, h:filter_enabled("Other", "Other Filter"))
    assert_equal(1, #h.logs)
end)

test("a missing filter does not mutate another filter", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Camera", "Color Correction", true)
    h:load({ source_name = "Camera", filter_name = "Missing" })
    assert_equal(true, h:filter_enabled("Camera", "Color Correction"))
    assert_equal(1, #h.logs)
end)

test("changing targets restores the old filter and gates the new filter", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Camera A", "Background Removal", true)
    h:add_filter("Camera B", "Background Removal", false)
    h:load({ source_name = "Camera A", filter_name = "Background Removal" })
    h:update({ source_name = "Camera B", filter_name = "Background Removal" })
    assert_equal(true, h:filter_enabled("Camera A", "Background Removal"))
    assert_equal(false, h:filter_enabled("Camera B", "Background Removal"))
    h:event(h.obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STARTED, true)
    assert_equal(true, h:filter_enabled("Camera B", "Background Removal"))
    h:unload()
    assert_equal(false, h:filter_enabled("Camera B", "Background Removal"))
end)

test("properties list available sources and selected source filters", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Camera", "Background Removal", true)
    h:add_filter("Camera", "Color Correction", true)
    h:load({ source_name = "Camera", filter_name = "Background Removal" })
    local props = h:properties()
    assert_items(props.source_name, { "", "Camera" })
    assert_items(props.filter_name, { "", "Background Removal", "Color Correction" })
end)


test("scene collection reload resolves and gates the replacement target", function()
    local h = harness({ virtualcam_active = false })
    h:add_filter("Camera", "Background Removal", true)
    h:load({ source_name = "Camera", filter_name = "Background Removal" })
    h:event(h.obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CLEANUP, false)
    h:replace_filter("Camera", "Background Removal", true)
    h:event(h.obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGED, false)
    assert_equal(false, h:filter_enabled("Camera", "Background Removal"))
end)
```

- [ ] **Step 2: Add the executable test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua"
test_file="$repo_root/tests/obs-virtual-camera-filter-gate/test.lua"

luac -p "$script"
lua "$test_file" "$script"
```

- [ ] **Step 3: Run the harness and verify RED**

Run: `tests/obs-virtual-camera-filter-gate/run.sh`

Expected: nonzero exit because `dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua` does not exist.

- [ ] **Step 4: Commit the failing harness**

```bash
git add tests/obs-virtual-camera-filter-gate
git commit -m "test(obs): define virtual camera filter lifecycle"
```

### Task 2: Implement the OBS controller

**Files:**
- Create: `dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua`
- Test: `tests/obs-virtual-camera-filter-gate/test.lua`

- [ ] **Step 1: Add target resolution and deduplicated warnings**

Implement `resolve_filter(source_name, filter_name)` using `obs_get_source_by_name` and `obs_source_get_filter_by_name`. Return both references on success, release the source before returning failure, and use a `last_warning` string to log each repeated resolution problem once.

```lua
local function resolve_filter(selected_source, selected_filter)
    if selected_source == "" or selected_filter == "" then
        warn_once("Select both a source and a filter")
        return nil, nil
    end

    local source = obs.obs_get_source_by_name(selected_source)
    if source == nil then
        warn_once(string.format("Source not found: %s", selected_source))
        return nil, nil
    end

    local filter = obs.obs_source_get_filter_by_name(source, selected_filter)
    if filter == nil then
        obs.obs_source_release(source)
        warn_once(string.format("Filter not found on %s: %s", selected_source, selected_filter))
        return nil, nil
    end

    last_warning = nil
    return source, filter
end
```

- [ ] **Step 2: Add target adoption, synchronization, and restoration**

Track only names and the selected filter’s original enabled state. Never retain OBS references beyond one operation.

```lua
local function adopt_and_sync()
    local source, filter = resolve_filter(source_name, filter_name)
    if source == nil then return false end

    managed_target = {
        source_name = source_name,
        filter_name = filter_name,
        original_enabled = obs.obs_source_enabled(filter),
    }
    obs.obs_source_set_enabled(filter, obs.obs_frontend_virtualcam_active())
    release_filter(source, filter)
    return true
end

local function restore_target()
    if managed_target == nil then return end
    set_filter_enabled(managed_target.source_name, managed_target.filter_name,
        managed_target.original_enabled)
    managed_target = nil
end
```

`script_update` restores an old target before adopting a different one. Repeated updates for the same target synchronize without replacing the recorded original state.

- [ ] **Step 3: Add Virtual Camera and scene-collection lifecycle handling**

```lua
local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STARTED then
        synchronize(true)
    elseif event == obs.OBS_FRONTEND_EVENT_VIRTUALCAM_STOPPED then
        synchronize(false)
    elseif event == obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CLEANUP then
        managed_target = nil
    elseif event == obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGED then
        last_warning = nil
        synchronize(obs.obs_frontend_virtualcam_active())
    elseif event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
        synchronize(obs.obs_frontend_virtualcam_active())
    end
end

function script_load(settings)
    obs.obs_frontend_add_event_callback(on_frontend_event)
    event_callback_registered = true
    synchronize(obs.obs_frontend_virtualcam_active())
end

function script_unload()
    if event_callback_registered then
        obs.obs_frontend_remove_event_callback(on_frontend_event)
        event_callback_registered = false
    end
    restore_target()
end
```

- [ ] **Step 4: Add configurable Source and Filter dropdowns**

Build sorted list properties with an empty prompt value. Populate filters from `obs_source_enum_filters(source)`, release enumerated lists with `source_list_release`, and refresh the filter list from a Source modified callback.

```lua
function script_properties()
    local props = obs.obs_properties_create()
    local source_property = obs.obs_properties_add_list(
        props, "source_name", "Source",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    local filter_property = obs.obs_properties_add_list(
        props, "filter_name", "Filter",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)

    populate_sources(source_property)
    populate_filters(filter_property, source_name)
    obs.obs_property_set_modified_callback(source_property, source_modified)
    return props
end
```

Add a `script_description` that states the plugin’s “Stop filter when source is inactive” option must be unchecked.

- [ ] **Step 5: Run the harness and verify GREEN**

Run: `tests/obs-virtual-camera-filter-gate/run.sh`

Expected: `7 tests passed` and exit code 0.

- [ ] **Step 6: Commit the implementation**

```bash
git add dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua
git commit -m "feat(obs): gate background filter with virtual camera"
```

### Task 3: Verify repository and target integration

**Files:**
- Verify: `dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua`
- Verify: `tests/obs-virtual-camera-filter-gate/run.sh`

- [ ] **Step 1: Run the focused harness from a clean shell**

Run: `bash tests/obs-virtual-camera-filter-gate/run.sh`

Expected: `7 tests passed` and exit code 0.

- [ ] **Step 2: Check syntax and whitespace**

Run: `luac -p dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua && git diff --check HEAD~2..HEAD`

Expected: no output and exit code 0.

- [ ] **Step 3: Verify the chezmoi destination**

Run: `chezmoi target-path "$(pwd)/dot_config/obs-studio/scripts/virtual-camera-filter-gate.lua"`

Expected: `/home/ty/.config/obs-studio/scripts/virtual-camera-filter-gate.lua`.

- [ ] **Step 4: Confirm the worktree is clean**

Run: `git status --short`

Expected: no output.
