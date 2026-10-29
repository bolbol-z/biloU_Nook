# Media UI Design

Date: 2026-10-26
Task: `media-ui`
Status: approved for implementation

## Goal

Add a Media `NotchModule` with:

- An expanded now-playing widget: artwork, title, artist, optional album, draggable progress, elapsed/remaining time, and transport controls.
- A compact closed-notch live activity: artwork on the left, equalizer on the right, only while playing.
- A `mediaCompactEnabled` setting, default `true`.
- An empty state when no track is available.
- Tests for formatting, state mapping, live-activity selection, sizing, and artwork thumbnails.

Media is registered first and becomes the default expanded module. The notch shape code and existing notch animations are not edited.

## Physical notch measurement

Measured before implementation with `NSScreen` on the current built-in display:

- `safeAreaInsets.top = 32`
- `auxiliaryTopLeftArea = (0, 924, 646, 32)`
- `auxiliaryTopRightArea = (825, 924, 645, 32)`
- Physical notch width = `825 - 646 = 179`
- Closed footprint width = `179`

The closed footprint exactly matches the physical notch. Without adjustment, compact artwork and the equalizer would sit behind hardware. While the live activity is active, the closed width expands to `physicalWidth + 72 = 251`, using the existing size animation. Height stays unchanged.

For displays without a physical notch, the physical width is treated as `nil`; the closed footprint only widens when it is narrower than the compact content minimum (`120pt`).

## Architecture

- `NotchModule` gains:
  - `liveActivityPriority: Int` (default `0`)
  - `isLiveActivityActive: Bool` (default `false`)
  - `liveActivity: AnyView?` (default `nil`)
- `ModuleRegistry.activeLiveActivity` picks the highest-priority enabled module whose live activity is currently active. Ties preserve registration order. Only one live activity is returned.
- Media reports priority `10` and is active when compact media is enabled and playback is playing.
- `NotchRootView` renders one non-interactive live-activity overlay above the active module compact icon. The overlay uses the same frame and `NotchShape` mask.
- Media's compact overlay paints black, so when visible it supersedes the active-tab icon. When inactive it returns `EmptyView`, so the normal compact icon remains.
- The closed metrics widen only while a live activity is active. The existing `openFootprint` animation expands them; `closeFootprint` restores them.
- The physical-width comparison is a pure helper so it can be tested with synthetic notch and non-notch geometry.

## Compact performance

- `NowPlayingService` exposes a stored, equatable `liveActivityState` that changes only for:
  - `isPlaying`
  - track identity
  - artwork byte count
- Elapsed-only snapshot ticks do not mutate this state, so the compact view does not re-render on elapsed ticks.
- The compact content is a stable `Equatable` view wrapped by a thin `AnyView`.
- Artwork is decoded with ImageIO into a thumbnail sized for the display and cached by artwork identity plus pixel size. It is not decoded per elapsed tick.
- The equalizer uses `TimelineView` at a maximum of 20fps and is paused when not playing.

## Expanded layout

- Preferred size: `520 x 176`.
- Existing module tab bar remains at the top.
- Track content:
  - 92pt artwork, rounded 12pt.
  - Title at 16pt, artist at 12pt, optional album at 10pt.
  - Title and artist marquee only when their natural width exceeds the container. Reduced Motion disables marquee and truncates instead.
  - Progress bar with elapsed on the left and `-remaining` on the right. Durations of one hour or more use `h:mm:ss`.
  - Previous, play/pause, and next controls call `NowPlayingService`.
- Empty state: music-note placeholder, “Nothing playing”, and a short hint to start Spotify, Music, or browser playback.

## Progress seeking

- While dragging, show a local preview fraction and ignore incoming elapsed updates.
- Send exactly one `seek(to:)` on release.
- Clear the local preview immediately after release, so unsupported or failed seeks snap back to the last real elapsed value.
- Disable seeking when duration is `<= 0`; show unknown remaining as `--:--`.

## Settings

- Add `mediaCompactEnabled` to `SettingsStore`, persisted in `UserDefaults`, default `true`.
- Add a Media section with the toggle to the existing Settings window.
- No other settings-window sections are introduced in this task.

## Tests

- `MediaFormatting`: seconds, minutes, hours, negative, NaN, and unknown remaining.
- `MediaViewState`: nil/blank snapshot, paused track, playing track, progress clamping, play/pause symbol.
- `LiveActivityLayout`: exact-notch widening, already-wide footprint unchanged, no-notch minimum, inactive unchanged.
- `ModuleRegistry`: highest priority wins, inactive highest-priority falls through, ties preserve order, disabled modules excluded.
- `NowPlayingService.liveActivityState`: elapsed ticks do not mutate it; play/pause, track, and artwork changes do.
- `ArtworkDecoder`: thumbnail dimensions are bounded by the requested pixel size.
- Existing render sanity, registry, and state tests remain green.

## Out of scope

- Changing `NotchShape`, notch open/close animations, or the window/panel.
- New haptics.
- A full settings redesign.
- Playback-provider behavior changes.

## Acceptance

- Media is the default tab, with A/B still available.
- Compact artwork/equalizer are visible outside the hardware notch.
- Compact view remains static across elapsed ticks.
- Seeking sends one command on release and does not get stuck on an unsupported seek.
- Build, full tests, and `--smoke-test` pass.
- Visual behavior remains `VISUAL UNVERIFIED` until the user confirms it.
