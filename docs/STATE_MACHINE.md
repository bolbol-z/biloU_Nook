# State Machine

`NotchState` is the only owner of notch phase and timing. Views and monitors
render or request changes; they never write phase directly.

## Phases

```swift
enum NotchPhase: Equatable {
    case closed
    case opening
    case open
    case closing
}
```

There is no `peek` phase.

## Owned state

| Property | Meaning |
| --- | --- |
| `phase` | Current phase. |
| `openOnHover` | Whether hover intent may open the notch. |
| `intentDelay` | Hover intent delay in seconds. |
| `closeDelay` | Delay before leaving `closing`. |
| `minStateDwell` | Minimum time before a close can be accepted. |
| `lastCloseTime` | Clock time of the last accepted close. |
| `lastOpenTime` | Clock time of the last accepted open. |
| `outsideSince` | First time the watchdog saw the pointer outside. |
| `generation` | Invalidates delayed work after a newer request. |
| `intentHandle` | Pending hover-intent timer. |
| `closeHandle` | Pending close timer. |

Dependencies are injected:

- `clock: NotchClock`
- `scheduler: NotchScheduler`
- `haptics: HapticPlaying`

Production uses `NotchState.shared`; tests build isolated instances with fake
dependencies.

## Triggers and reasons

```swift
enum OpenTrigger {
    case hover
    case click
    case gesture
    case programmatic
}

enum CloseReason {
    case mouseLeft
    case gesture
    case click
    case programmatic
    case watchdog
    case system
}
```

The state machine records the trigger/reason in DEBUG logs. Timing policy is the
same for every trigger and reason except the hover gate in `enterIntent`.

## API

```swift
func requestOpen(trigger: OpenTrigger)
func requestClose(reason: CloseReason)
func closeImmediately(reason: CloseReason)
func enterIntent()
func cancelIntent()
func cancelPending()
func watchdogTick(isOutside: Bool)
func toggle()
func close()
func open()
```

`closeImmediately` is not a bypass. It delegates to
`requestClose(reason:)`, so the close dwell guard still applies.

`toggle` cancels pending work first. It closes when the phase is `open` or
`opening`, otherwise it requests an open with `.click`.

## Transition table

| Phase | Event | Condition | Result |
| --- | --- | --- | --- |
| closed | `enterIntent` | `openOnHover == false` | No-op. |
| closed | `enterIntent` | `intentDelay > 0` | Schedule an open after the delay. |
| closed | `enterIntent` | `intentDelay <= 0` | Call `requestOpen(.hover)`. |
| closed | `requestOpen` | Any trigger | Cancel timers, increment generation, haptic, `opening`, then `open`. |
| opening | `requestOpen` | Any trigger | Rejected: already opening. |
| open | `requestOpen` | Any trigger | Rejected: already open. |
| closing | `requestOpen` | Dwell since `lastCloseTime` not met | Rejected. |
| closing | `requestOpen` | Dwell met or zero | Cancel close, haptic, `opening`, then `open`. |
| opening | `requestClose` | Dwell since `lastOpenTime` not met | Rejected. |
| open | `requestClose` | Dwell since `lastOpenTime` not met | Rejected. |
| open | `requestClose` | Dwell met or zero | Cancel timers, haptic, `closing`, schedule `closed`. |
| closing | `requestClose` | Any reason | Rejected: already closing. |
| closed | `requestClose` | Any reason | Rejected: already closed. |

`opening` is transient: `requestOpen` sets `opening`, then immediately sets
`open` in the same synchronous call. There is no opening timer.

`closing` lasts for `closeDelay`. With the default `closeDelay = 0`, the
scheduled close still runs asynchronously on the next scheduler turn; the phase
is `.closing` until that work runs.

## Haptics

Accepted transitions call the single `HapticsService`:

- accepted open: `play(.open)` before the phase write,
- accepted close: `play(.close)` before the phase write.

The haptic service checks `SettingsStore.hapticsEnabled`. It rate-limits the same
kind to 0.25 s and opposite open/close kinds to 0.12 s. The state machine does
not call `NSHapticFeedbackManager` directly.

## Delayed work and cancellation

`requestOpen`:

1. rejects when already `open` or `opening`,
2. when `closing`, rejects if `minStateDwell` has not elapsed since
   `lastCloseTime`,
3. cancels pending intent and close work,
4. increments `generation`,
5. plays the open haptic,
6. sets `phase = .opening`,
7. sets `phase = .open`,
8. records `lastOpenTime`.

`requestClose`:

1. rejects when `closed` or `closing`,
2. rejects if `minStateDwell` has not elapsed since `lastOpenTime`,
3. cancels pending intent and close work,
4. increments `generation`,
5. captures the new generation,
6. plays the close haptic,
7. sets `phase = .closing`,
8. records `lastCloseTime`,
9. clears `outsideSince`,
10. schedules the close after `closeDelay`; that work only sets `.closed` if the
    captured generation is still current and the phase is still `.closing`.

`enterIntent`:

1. returns when `openOnHover` is false,
2. returns when `open` or `opening`,
3. when `closing`, returns if `minStateDwell` has not elapsed since
   `lastCloseTime`,
4. cancels pending work and increments `generation`,
5. with `intentDelay <= 0`, calls `requestOpen(.hover)`,
6. otherwise schedules `requestOpen(.hover)` after the delay, guarded by the
   captured generation.

`cancelIntent` cancels only the hover-intent handle. `cancelPending` cancels both
the close and intent handles. Neither changes phase, `lastOpenTime`,
`lastCloseTime`, or `outsideSince`.

## Watchdog

`Watchdog` ticks every 0.25 s on the main run loop and calls:

```swift
NotchState.shared.watchdogTick(isOutside: isOutside)
```

The watchdog uses `InteractionRegion.interactiveRect` for the current phase and
compares the current mouse location with `ZoneMath.contains`.

Rules:

- `closed`: clear `outsideSince` and return.
- pointer inside: clear `outsideSince` and return.
- pointer outside with no `outsideSince`: record the time and return.
- pointer outside for at least 0.5 s: clear `outsideSince`, call
  `closeImmediately(.watchdog)`, which delegates to `requestClose`.
- if the close is rejected by `minStateDwell`, a later tick starts a new
  0.5 s outside interval and retries.

`Watchdog.shared` is started once through `NotchCoordinator.start()` and stopped
by the coordinator and on termination. `stop()` invalidates the timer.

## Hover intent and close delay

`NotchCoordinator.applySettings()` copies:

```text
SettingsStore.openOnHover      -> NotchState.openOnHover
SettingsStore.hoverIntentDelay -> NotchState.intentDelay
SettingsStore.closeDelay       -> NotchState.closeDelay
SettingsStore.minStateDwell    -> NotchState.minStateDwell
```

`MouseMonitor` reports raw edges. `NotchState` applies the timing policy.

- `intentDelay > 0`: a hover enter waits for the delay. Leaving the hot zone
  calls `cancelIntent()` through the coordinator.
- `closeDelay > 0`: the shape remains in `closing` for that long. Re-entering
  after the minimum dwell cancels the close and reopens.
- `minStateDwell > 0`: blocks closes immediately after opening. It is enforced
  in `requestClose`, so it applies to mouse, gesture, watchdog, and system
  closes alike. It also gates reopening during `closing`.

The defaults are `0` for all three. They are frozen for the cleanup phase.

## Interaction geometry

`InteractionRegion` has two separate concepts:

```text
hot zone (closed only)
  width  = closed notch width + 2 * hotPaddingX
  height = closed notch height + hotPaddingBelow + 6

interactive rect (watchdog / hover-leave / click-through)
  closed  = width + 6,  height + 6
  opening = module width + 12, height + 6
  open    = module width + 12, height + 6
  closing = module width + 24, height + 12 + 6
```

All rects are centered on the screen and hang from the top edge. Hit testing is
inclusive:

```swift
rect.minX <= point.x && point.x <= rect.maxX
rect.minY <= point.y && point.y <= rect.maxY
```

Focus and tap open the notch. Escape closes it. A vertical scroll of 12 pt opens
or closes; a horizontal scroll of 24 pt changes modules while open. Gestures are
only considered inside the hot zone or the current interactive rect.

## Sleep and teardown

`NotchCoordinator` calls `closeImmediately(.system)` on
`NSWorkspace.willSleepNotification`. On wake, `NotchPanelController` repositions
the panel and refreshes geometry; it does not reopen the notch.

`AppDelegate.applicationWillTerminate` stops the panel controller, the shared
watchdog, and the now-playing service. `NotchPanelController.stop()` removes
observers, stops the coordinator, orders the panel out, and releases the hosting
view.

## Test coverage

`BilouNookTests/NotchStateTests.swift` covers:

- open is immediate,
- close waits for `closeDelay`,
- early close rejected by minimum dwell,
- watchdog close after 0.5 s outside,
- re-entry cancels a pending close,
- hover opens immediately,
- `closeImmediately` uses the normal closing path,
- hover intent schedules an open,
- `openOnHover = false` blocks hover but not click.

`BilouNookTests/NotchCharacterizationTests.swift` covers the open-then-close
haptic sequence and settings-driven timing. `BilouNookTests/NotchCoordinatorTests.swift`
covers phase-driven content, click-through, module resizing, live activity
metrics, stop idempotence, motion plans, and releasing the panel.
