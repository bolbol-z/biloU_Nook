# Media Polish Design

Date: 2026-10-26
Task: `media-polish`
Status: approved for implementation

## Scope

Polish the expanded Media module only. Changes stay in `Modules/Media/*`, tests,
project wiring, and the minimal `NowPlayingService` pending-seek change. Do not
change `NotchShape`, `Animations.swift`, the panel/window, or `HapticsService`.
No haptics are added to Media.

## Seek Smoothness

- The progress playhead renders from `MediaPlaybackAnchor`:
  `elapsedAtAnchor`, `anchorDate`, `isPlaying`, projected at ~30fps inside the
  progress bar's `TimelineView`. Service elapsed ticks do not replace the anchor.
- Time labels update from the same anchor at 1Hz or during drag.
- On release, the local anchor moves to the target immediately and
  `NowPlayingService.seek(to:)` stores `pendingSeek(target, issuedAt)`.
- While pending, provider positions more than `1.5s` from the expected position
  are rejected. A position within tolerance confirms and clears pending.
  Pending clears after `2s`, accepting the next provider position as real.
- Unsupported seeks (unknown duration, missing provider, non-finite target) do
  not enter pending. Confirmation or timeout changes animate back from the
  optimistic position.
- Dragging uses no implicit track animation, shows a live time bubble, and
  sends exactly one seek on release. Taps seek. The bar uses a
  high-priority drag gesture so module swiping cannot consume it.
- Track thickness springs from `4pt` to `7pt` on hover/drag in a `24pt` hit
  area. The thumb is visible only on hover/drag. Hover uses the pointing-hand
  cursor. Unknown duration is disabled and shows `--:--`.
- DEBUG builds log the seek position timeline for 3 seconds.

## Layout

- Module size stays `520 x 176`.
- Media insets: `24pt` horizontal, `2pt` top inside the module content (the
  module tab bar already clears the hardware notch), `18pt` bottom.
- Left: `108pt` artwork, `14pt` radius, soft shadow, cached source-app icon
  badge. Paused artwork scales to `0.92`.
- Right: uppercase app name, title, artist, optional album; progress with times
  under its ends; centered transport controls.
- Controls: prev/next `20pt`; play/pause `30pt` in a `44pt` hit area with hover
  circle and press scale. Play/pause symbol replacement animates.
- Previous restarts at `elapsed > 3s`, otherwise sends previous track. Providers
  only expose plain previous commands, so this logic lives in Media.
- Track changes crossfade artwork and slide/fade text unless Reduced Motion.
- Ambient tint is one average artwork color, computed off-main from a
  downscaled bitmap and cached by artwork identity. Gradient opacity stays at or
  below `15%` over a black base.
- Empty state uses the same insets with icon, title, and secondary line.

## Verification

- Unit tests: anchor math, pending seek (stale, confirm, timeout, unsupported),
  transport previous rule, layout metrics, source-icon cache.
- DEBUG `ImageRenderer` test writes PNG fixtures at `520 x 176` into
  `build/screens/`: playing, paused, long title, no album, unknown duration,
  empty, dragging.
- Build with `-derivedDataPath ./build`, full tests, `scripts/smoke.sh`, and
  `--smoke-test`.
- Commit `Phase1-P9: media polish`, tag `v-media-polish`.
- Visual confirmation remains the user's responsibility.
