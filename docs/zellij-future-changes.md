# Zellij: Future Changes to Watch

Tracking upstream features and plugins that would improve the zellij setup once available.

## Auto Tab Rename (blocked on zellij release)

**Plugin:** [vmaerten/zellij-tab-rename](https://github.com/vmaerten/zellij-tab-rename)

Automatically renames tabs based on CWD, running process, or git root. Closest thing to tmux's `automatic-rename` behavior. Supports `source "process"` mode which shows `nvim`, `cargo`, etc. and falls back to directory name for shells.

**Blocked on:** `CwdChanged` event from [zellij PR #4546](https://github.com/zellij-org/zellij/pull/4546) — not yet in a release. Current zellij 0.43.1 does not support it.

**When available:** Add to `load_plugins` in `config.kdl.tmpl` with `source "process"` and `git_root "true"`.

## Clickable Session Name (zjstatus feature request)

zjstatus's `{session}` widget has no click behavior. Clicking it to open the session manager (`zellij:session-manager`) would match the UX of `{tabs}` (click to switch) and `{swap_layout}` (click to cycle).

**Status:** Not implemented. Would need a feature request on [dj95/zjstatus](https://github.com/dj95/zjstatus/issues).

## Autolock Status Indicator

The `zellij-autolock` plugin's enabled/disabled state is invisible to other plugins. `MessagePlugin` from keybindings sends `CustomMessage` events, but zjstatus pipes expect `PipeMessage` events — they're different event types in zellij's architecture.

**What would fix it:**
- zellij adding a silent `Run` action for keybindings (no pane opened)
- zellij unifying `CustomMessage` and `PipeMessage` so `MessagePlugin` can reach zjstatus pipes
- autolock exposing its state via a file or pipe

## Mouse Button Bindings

Zellij's keybinding system only supports keyboard inputs. No mouse button bindings (middle-click to close tab, right-click context menu). Mouse events are either passthrough to terminal apps or internal UI only.

**Status:** No known proposal. Would need a zellij core feature request.

## Image Support in Multiplexers (yazi/superfile)

Terminal image protocols (Kitty graphics, sixel) don't pass through zellij correctly. Tools like yazi and superfile that rely on inline image rendering show broken or no images inside zellij panes.

**Status:** Known zellij limitation. Partial sixel support exists but Kitty graphics protocol passthrough is incomplete. Track [zellij-org/zellij#2790](https://github.com/zellij-org/zellij/issues/2790) and related issues.

## Independent Pane Border Colors

Pane border colors are tied to the theme's component system (`frame_selected`, `frame_unselected`, `frame_highlight`). The current custom theme (`catppuccin-mocha-subtle`) uses surface0/1/2 for subtle borders. If zellij adds dedicated border color settings independent of the component theme, the workaround theme could be simplified.
