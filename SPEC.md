# RaidGroupWrap — Feature Spec

Blizzard raid frames with "Separate Groups" put every raid group on one long line. RaidGroupWrap caps how many groups share a line and wraps the rest onto a new line.
Blizzard raid frames, no restyle, no libraries. Selling point: **zero cost when idle, tiny cost when it works.**

## Scope

- Flavors: Retail + WoW: Forever (one TOC, `## Interface-*` lines). No Classic flavors.
- Blizzard's own raid frames only (`CompactRaidFrameContainer`).
- English only. Every player-visible string goes through `Localization.Text("...")` so languages can be added later.

## The setting

One slider, docked under the **Raid Frames** settings dialog in Edit Mode.

| Setting | Range | Default |
| --- | --- | --- |
| Groups Per Row / Groups Per Column | 1–8 whole numbers | 8 |

- **8 = off.** 8 groups per line is Blizzard's own layout; the addon does no work on layout at 8.
- Label: "Groups Per Row" for Separate Groups (Vertical), where groups sit side by side and extra groups wrap to a new row below. "Groups Per Column" for Separate Groups (Horizontal), where groups stack and extra groups wrap to a new column on the right.
- Shown only while the Raid Frames system is selected **and** a Separate Groups mode is active. Combine Groups already has Blizzard's own Row Size setting, so the slider hides there and the addon leaves those frames alone.
- The panel closes with the Edit Mode settings dialog.
- Changing the slider re-arranges the groups at once.
- Account-wide SavedVariables: `RaidGroupWrapDB` (`perLine`). Saved values are rounded and clamped to 1–8 on load; anything else falls back to 8. Unknown keys are dropped.

## Layout

- Groups keep Blizzard's order, size, spacing and starting point; only the line breaks change.
- A row is as tall as its tallest group; a column is as wide as its widest group.
- Gap between groups and lines = Blizzard's horizontal spacing (side by side) or vertical spacing (stacked); missing spacing counts as 0.
- The Edit Mode selection box is resized to fit the wrapped block.
- **Pets are not moved.** Raid "Display Pets" frames (off by default) keep Blizzard's position.

## Combat

Raid group frames hold secure unit buttons and can't move in combat. A wrap requested in combat is skipped and retried once when combat ends. The combat-end event is registered only while that retry is pending.

## Performance rules (non-negotiable)

1. **No `OnUpdate` handlers, no timers.** Code runs only when Blizzard lays out the raid frames, when the slider changes, or once after combat.
2. **No libraries.**
3. **Events registered only while needed** — the combat-end event only while a wrap is pending.
4. **Zero work when off** — at 8 groups per line the layout hook returns before touching any frame.
5. **No garbage per layout** — group, size and position buffers are reused.
6. Release zip is minified by CI.

## Taint rules (non-negotiable)

See `AGENTS.md` → Taint rules. In short: secure hooks and `HookScript` only, no field writes on Blizzard frames, no Blizzard Lua layout calls, panel parented to `UIParent`, combat deferral, `SetSize` for the container.

## Out of scope (decided)

- Combine Groups modes (Blizzard has Row Size there), party frames, arena frames.
- Moving pet frames, reordering or sorting groups, per-group positions.
- Frame restyling, custom spacing, per-character settings, profiles, slash command, minimap button, options panel outside Edit Mode.
- Classic flavors.
