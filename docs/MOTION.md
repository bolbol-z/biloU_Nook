# Motion

Motion is split into two vocabularies:

- `Animations.swift`: notch metrics, content visibility, module changes, and
  shared timing constants.
- `MediaMotion.swift`: media artwork, text, controls, tint, and Reduce Motion
  handling.

Reduce Motion is read separately by the coordinator and by media views. The
coordinator uses `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`;
media views use the SwiftUI `accessibilityReduceMotion` environment value.

## Current coordinator plans

`NotchCoordinator` animates through `Animations.plan(for:reduceMotion:)`. These
are the values that drive the live notch:

| Transition | Normal plan |
| --- | --- |
| open metrics | spring, response 0.28, damping 0.9 |
| module change | spring, response 0.28, damping 0.9 |
| close metrics | spring, response 0.28, damping 1.0 |
| content show | spring, response 0.32, damping 0.9 |
| content hide | ease-in, 0.12 s |
| live activity | ease-in-out, 0.12 s |

All of these become `easeInOut(duration: 0.15)` when Reduce Motion is enabled.

Two timing constants gate visible work:

| Constant | Value | Use |
| --- | ---: | --- |
| `Animations.contentShowDelay` | 0.05 s | Content appears only if the phase is still `open` when the delay fires. |
| `Animations.clickThroughDelay` | 0.20 s | Click-through is restored only if the phase is still `closed` when the delay fires. |

## Legacy shared animations

`Animations.swift` also declares these reusable animations:

| Name | Definition | Current use |
| --- | --- | --- |
| `hoverOpen` | spring 0.28 / 0.9 | Not referenced by production views. |
| `hoverClose` | spring 0.28 / 1.0 | Not referenced by production views. |
| `hoverClosePure` | spring 0.28 / 1.0 | Not referenced by production views. |
| `openFootprint` | spring 0.28 / 0.9 | Not referenced by production views. |
| `closeFootprint` | spring 0.28 / 1.0 | Not referenced by production views. |
| `contentIn` | spring 0.24 / 0.9, delay 0.05 | Not referenced by production views. |
| `contentOut` | spring 0.18 / 0.95 | Module selection and horizontal swipe transitions. |
| `scrubFollow` | interactive spring 0.15 / 1.0, blend 0.25 | Not referenced by production views. |
| `scrubDrag` | interactive spring 0.22 / 0.58, blend 0.25 | Not referenced by production views. |

The Animation Lab displays older values for some of these names. The table
above is the code value; the Lab labels are not authoritative.

Module selection animates with `Animations.scaled(Animations.contentOut)`.
The content transition is an 18 pt horizontal offset plus opacity:
insertion moves from the swipe direction, removal moves the opposite way.

## Content timing

Open:

1. `phase` becomes `open`.
2. `metrics` animate to the active module's open size with the open spring.
3. After 0.05 s, if the phase is still `open`, `showContent` becomes true with
   the content-show spring.

Close:

1. `phase` becomes `closed`.
2. `showContent` becomes false with the content-hide ease-in.
3. `metrics` animate to the closed size with the close spring.
4. After 0.2 s, if the phase is still `closed`, click-through is restored.

There is no opening or closing timer beyond `closeDelay`; the visible shape
animation begins when the phase changes.

## Hover shape behavior

- Entering the hot zone requests an open; the shape expands with the open
  spring.
- The panel stays interactive while the pointer is inside the phase-correct
  rect.
- Leaving while open requests a close; the shape contracts with the close
  spring.
- Re-entering during `closing`, after `minStateDwell`, reverses to `open`.
- The watchdog uses the same close path after 0.5 s outside, so it uses the same
  close spring and haptic.

## Live activity behavior

A closed notch can display a module live activity. The active live activity is
chosen by `ModuleRegistry` priority.

- `liveActivityDidChange` only runs while `closed`.
- If an activity exists, closed metrics expand with the open plan.
- If the activity disappears, closed metrics collapse with the close plan.
- The overlay view animates its frame change with `liveActivityAnimation`
  (ease-in-out 0.12).
- Elapsed-time ticks do not change the live activity identity and do not
  trigger these animations. Play/pause, track, and artwork changes do.

## Media motion

| Name | Definition | Use |
| --- | --- | --- |
| `trackSpring` | spring 0.28 / 0.78 | Not referenced. |
| `artworkSpring` | spring 0.32 / 0.80 | Play/pause scale and artwork identity change. |
| `controlSpring` | spring 0.24 / 0.72 | Control hover fill, press scale, and hover background. |
| `trackChange` | spring 0.36 / 0.86 | Track title/artist transition. |
| `seekSettle` | spring 0.32 / 0.90 | Not referenced. |
| `tintFade` | ease-out 0.45 | Artwork tint color in `MediaView`. |

With Reduce Motion, every `MediaMotion.respectingReduceMotion` call becomes
`easeOut(duration: 0.01)`. That applies to:

- artwork play/pause scale,
- artwork identity changes,
- track text changes,
- control hover and press feedback.

Media animations do not call `Animations.scaled`, so the slow-motion setting
does not scale them.

`MarqueeText` does not start its repeating scroll when Reduce Motion is enabled.
Its normal duration is `clamp(overflow / 30, 1.8, 8.0)` seconds, linear and
autoreversing. `EqualizerView` is a 20 Hz timeline paused when not playing.
`MediaProgressBar` uses a 30 Hz timeline, paused when paused and not dragging.

## Slow motion

`Animations.timeScale` defaults to `1.0` and is not mutated in production.
`Animations.scaled` checks `SettingsStore.slowMotion`; when enabled it applies a
minimum scale of `4.0` by returning `animation.speed(1.0 / scale)`.

The DEBUG Animation Lab has its own local time-scale control; it does not
change the shared `Animations.timeScale`.

## Reduce Motion summary

| Surface | Normal | Reduce Motion |
| --- | --- | --- |
| Notch metrics/content/module/live activity | spring or 0.12-0.15 s ease | 0.15 s ease-in-out plan |
| Media artwork/text/controls | springs 0.24-0.36 | 0.01 s ease-out |
| Marquee scroll | repeating linear | disabled |

With Reduce Motion, the coordinator still animates metric changes, but uses the
0.15 s ease-in-out plan instead of a spring. The coordinator reads the system
value when `start()` runs. A later system setting change is picked up on the
next coordinator start, not continuously.

## Constants that must not change during cleanup

- `contentShowDelay = 0.05`
- `clickThroughDelay = 0.20`
- `reduceMotionDuration = 0.15`
- open/module springs 0.28 / 0.9
- close spring 0.28 / 1.0
- content-show spring 0.32 / 0.9
- content-hide ease-in 0.12
- live-activity ease-in-out 0.12
- haptic cooldowns 0.25 s same kind, 0.12 s opposite kind
- default `intentDelay`, `closeDelay`, and `minStateDwell` of `0`
