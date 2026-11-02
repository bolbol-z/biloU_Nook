# Architecture

This document describes the code in this repository on 2026-11-01. The code is
the source of truth; this is a map of it.

## Runtime shape

```text
BilouNookApp.main
  -> NSApplication + AppDelegate
     -> NotchPanelController.show()
        -> NotchPanel
        -> NotchCoordinator
        -> NSHostingView<NotchRootView>
     -> NowPlayingService.shared.start()

NotchRootView
  -> ModuleShellView
     -> ModuleRegistry
        -> MediaModule, ModuleA, ModuleB
  -> NotchShape + closed overlays
  -> NotchCoordinator (start/stop, metrics, content, hit testing)
```

There is one panel, one notch state machine, one settings store, and one module
registry per process.

## Layers

| Layer | Main files | Responsibility |
| --- | --- | --- |
| App | `App/BilouNookApp.swift`, `App/AppDelegate.swift` | Create `NSApplication`, own the panel controller, start and stop now-playing, handle DEBUG launch modes. |
| Window | `Window/NotchPanel.swift`, `Window/NotchPanelController.swift`, `Window/NotchAttachment.swift` | Borderless nonactivating panel, panel sizing, screen attachment, screen/wake/space observers. |
| Notch UI | `Notch/NotchRootView.swift`, `Notch/NotchOverlays.swift`, `Notch/NotchShape.swift`, `Notch/NotchGeometry.swift` | Root SwiftUI view, shape, closed overlays, geometry and metrics. |
| Coordination | `Notch/NotchCoordinator.swift` | Lifecycle of monitors, settings propagation, metrics, content visibility, click-through, motion selection. |
| State | `State/NotchState.swift` | The only owner of phase and timing. |
| Interaction | `Interaction/MouseMonitor.swift`, `Interaction/GestureMonitor.swift`, `Interaction/Watchdog.swift`, `Interaction/InteractionRegion.swift` | Mouse edges, scroll gestures, stall protection, hot/open rects. |
| Modules | `Modules/Core/*`, `Modules/Media/*`, `Modules/ModuleA/*`, `Modules/ModuleB/*` | Module contract, registry, tab layout, shell, media UI, placeholders. |
| Now Playing | `NowPlaying/*` | Provider abstraction, MediaRemote and AppleScript providers, snapshot normalization, seek reconciliation. |
| Settings | `Settings/SettingsStore.swift`, `Settings/SettingsWindow.swift` | Persisted preferences and the Settings window. |
| Haptics | `Haptics/HapticsService.swift` | The single haptic path and rate limiting. |
| Motion | `Animations/Animations.swift`, `Modules/Media/MediaMotion.swift` | Shared motion vocabulary and Reduce Motion behavior. |
| Debug | `Debug/*` | Overlay, Animation Lab, hotkeys, launch modes, diagnostics, benchmarks. All DEBUG-only. |

## Ownership and lifetime

`AppDelegate` creates exactly one `NotchPanelController` in
`applicationDidFinishLaunching`, shows it, then starts `NowPlayingService`.
`applicationWillTerminate` stops the panel controller, the shared watchdog, and
the now-playing service.

`NotchPanelController` owns:

- one `NotchPanel`,
- one `NotchCoordinator`,
- one `NSHostingView<NotchRootView>`.

`show()` is not designed to be called twice; `stop()` is idempotent. `stop()`
stops the coordinator, removes observers, orders the panel out, and drops the
content view and hosting view. The panel has `isReleasedWhenClosed = false` and
is never `close()`d.

`NotchRootView` owns no long-lived monitors. On appear it calls
`coordinator.start()` and installs DEBUG tooling. On disappear it calls
`coordinator.stop()`.

`NotchCoordinator` holds the panel weakly through `WeakPanelReference`. Tests
assert that neither the coordinator nor the root view retains the panel.

`NotchState.shared` owns phase and timing. Views, monitors, the watchdog, and
the coordinator are consumers. Tests construct separate `NotchState` instances
with a fake clock, fake scheduler, and recording haptics.

`SettingsStore.shared` owns persisted preferences. The coordinator copies the
four state-timing values into `NotchState`; geometry reads the visual values
directly through `NotchGeometry.live`.

`ModuleRegistry.shared` owns the ordered module list and the active module.
Module order is registration order. The first enabled module is selected at
startup.

## Panel and screen attachment

`NotchPanel` is a borderless `NSPanel` with:

- `.nonactivatingPanel`, no key/main window behavior,
- `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle`,
- `isFloatingPanel = true`, `hidesOnDeactivate = false`, `canHide = false`,
- `becomesKeyOnlyIfNeeded = true`, `acceptsMouseMovedEvents = true`,
- `isReleasedWhenClosed = false`,
- level `mainMenu + 3`,
- a transparent background and no shadow.

Panel width comes from the active module set:

```text
panel width  = widest enabled module preferred width + 24 + 24
panel height = 220
fallback     = NotchPresets.open width + 48
```

The frame is centered horizontally under the target screen's top edge and
backing-aligned through `NotchAttachment.panelFrame`.

`ScreenResolver` supports built-in, main, and follow-mouse preferences. The
default is built-in, with a fallback to the main screen. `NotchPanelController`
repositions the panel on display changes, screen wake, system wake, and active
space changes.

## Geometry

`NotchGeometry` resolves a hardware notch from the screen's auxiliary top areas
and safe-area top inset:

```text
notch x      = auxiliaryTopLeft.maxX
notch y      = screen.maxY - safeAreaTop
notch width  = auxiliaryTopRight.minX - auxiliaryTopLeft.maxX
notch height = safeAreaTop
```

If there is no hardware notch, a virtual notch is centered on the screen:

```text
width  = 200
height = max(32, safeAreaTop)
```

The closed shape adds a 0.5 pt overlap on each side and bottom. Open metrics
come from the active module's preferred size. Widths are snapped to an even
number of backing pixels; heights are pixel-ceiled. Radii are clamped to half
the smallest shape dimension.

Constants in `NotchGeometry`:

| Constant | Value |
| --- | ---: |
| `overlap` | 0.5 |
| `virtualWidth` | 200 |
| `virtualHeight` | 32 |
| `forbiddenZoneExpansion` | 6 |

`contentTop` is always `notch height + 6`.

The forbidden zone is the notch rect expanded horizontally by 6 pt on each
side. `ModuleTabLayout` places tabs outside it. On a physical notch, tabs split
into left and right flanks; without one, they use a centered strip inside the
virtual band.

## Interaction and click-through

```text
MouseMonitor (global + local mouseMoved)
  -> onEnterHotZone -> NotchState.enterIntent()
  -> onLeaveOpenArea -> NotchState.requestClose(.mouseLeft)
  -> onMouseMove -> NotchCoordinator.updateMouseInteraction()

Watchdog (0.25 s)
  -> phase-correct interactive rect
  -> NotchState.watchdogTick(isOutside:)

GestureMonitor (global + local scrollWheel)
  -> vertical swipe: open/close at 12 pt accumulated
  -> horizontal swipe: module change at 24 pt while open
```

`InteractionRegion` builds the hot zone from the closed metrics plus
`hotPaddingX`, `hotPaddingBelow`, and the fixed 6 pt top extension. Open and
closing rects are derived from the active module's preferred size. Closing gets
extra margin so a re-entry can cancel the close.

`ZoneMath.contains` is inclusive on all edges.

The coordinator starts with `ignoresMouseEvents = true`. It only writes the
property when the boolean changes. While the pointer is inside the phase-correct
interactive rect, the panel receives events; outside it, events pass through.
After a close, click-through is re-enabled after 0.2 s if the phase is still
closed.

`MouseMonitor` has an optional fly-by guard. When enabled, moves faster than
`flyBySpeedThreshold` points per second are ignored for hot-zone entry.

`GestureMonitor` only handles gestures inside the hot zone or the current
interactive rect. It is disabled by `verticalGesturesEnabled`.

## Coordinator

`NotchCoordinator` is the single adapter between AppKit/SwiftUI and the state
machine. It is `@MainActor` and `@Observable`.

Inputs are injectable: screen provider, mouse monitor, watchdog, gesture
monitor, sleep observer, scheduler, Reduce Motion provider, and the
`ignoresMouseEvents` setter. Tests use fakes for all of them.

On `start()` it:

1. applies settings to `NotchState`,
2. computes metrics for the current phase,
3. forces click-through until the pointer is evaluated,
4. subscribes to settings changes,
5. starts the sleep observer, mouse monitor, watchdog, and gesture monitor.

On `stop()` it clears closures, stops every monitor, cancels settings and timer
handles, and leaves `NotchState` unchanged.

Phase changes drive:

| Phase change | Coordinator action |
| --- | --- |
| to `open` | Animate open metrics; after 0.05 s reveal content if still open. |
| to `closed` | Hide content immediately, animate closed metrics, enable click-through after 0.2 s if still closed. |
| active module change while open | Recompute open metrics with module-change animation. |
| live activity change while closed | Recompute closed metrics with open/close footprint animation. |

## Module system

`NotchModule` is the registration contract:

```swift
protocol NotchModule: Identifiable {
    var id: String { get }
    var title: String { get }
    var icon: String { get }
    var compactView: AnyView? { get }
    var expandedView: AnyView { get }
    var preferredSize: CGSize { get }
    var isEnabled: Bool { get }
    var liveActivityPriority: Int { get }
    var isLiveActivityActive: Bool { get }
    var liveActivity: AnyView? { get }
}
```

Defaults: no compact view, enabled, priority 0, no live activity.

The shared registry is the single registration point:

```swift
ModuleRegistry.shared = ModuleRegistry(modules: [
    MediaModule(),
    ModuleA(),
    ModuleB(),
])
```

`ModuleA` and `ModuleB` are visible placeholders; `MediaModule` is the live
feature module. New features should be added here rather than by editing the
window, root view, or coordinator.

`ModuleRegistry` exposes:

- the ordered module list,
- enabled modules,
- the effective active module,
- `activeLiveActivity`, chosen by highest `liveActivityPriority` among enabled
  modules whose `isLiveActivityActive` and `liveActivity` are non-nil,
- next/previous selection with wraparound.

Ties preserve registration order.

`ModuleTabLayout` is pure geometry. It uses 24 pt hit targets, 4 pt preferred
spacing, and an 8 pt forbidden-zone gap. Spacing is reduced before hit targets
are shrunk. An odd module count puts the extra tab on the left.

`ModuleShellView` renders tabs from those frames and moves horizontal swipes
into the registry. Content transitions use an 18 pt directional offset plus
opacity.

## Now-playing pipeline

```text
AppDelegate
  -> NowPlayingService.start()
     -> MediaRemoteNowPlayingProvider          (first choice)
        -> perl + mediaremote-adapter.pl
        -> embedded MediaRemoteAdapter.framework
     -> AppleScriptNowPlayingProvider(.spotify) (fallback)
     -> AppleScriptNowPlayingProvider(.music)   (fallback)

provider stream
  -> NowPlayingSnapshot
  -> NowPlayingService.normalized / accepted
  -> snapshot + liveActivityState
  -> MediaView / MediaCompactLiveActivity
```

`NowPlayingService` starts the first available provider. An unavailable provider
is skipped. A provider failure is dispatched to the main queue, recorded, and
the next provider is tried. When an application launches, AppleScript failures
are cleared and a higher-priority provider may take over.

`NowPlayingSnapshot` carries title, artist, album, artwork bytes and MIME type,
playback state, elapsed, duration, source bundle ID, optional parent bundle ID,
and update time. `sourceBundleIdentifier` prefers the parent. `trackIdentity`
uses the resolved source plus title, artist, and album. Artwork is preserved
when metadata for the same track omits it.

`NowPlayingLiveActivityState` contains only playback, track identity, and
artwork. Elapsed ticks do not invalidate the live activity view; play/pause,
track, and artwork changes do.

### MediaRemote provider

`MediaRemoteNowPlayingProvider` runs the bundled Perl script with the bundled
framework. It reads newline-delimited JSON, accepts `type = data` payloads, and
maps the payload to `NowPlayingSnapshot`. Artwork is base64-decoded. The provider
also watches for termination of the last reported player applications and emits
an empty snapshot when one exits.

Control commands use short-lived Perl processes:

| Command | Adapter call |
| --- | --- |
| play/pause | `send 2` |
| next | `send 4` |
| previous | `send 5` |
| seek | `seek <microseconds>` |

### AppleScript provider

The Spotify and Music providers each read six list items:

```text
player state, player position, title, artist, album, duration
```

A structured six-item list replaced the old pipe-delimited string, so pipes,
newlines, and Unicode in metadata cannot shift fields. Spotify duration is in
milliseconds and is divided by 1000; Music duration is in seconds. Only
`playing` and `paused` states with a non-empty title produce a snapshot.

Transport commands are sent through `NSAppleScript`. The app is not sandboxed
and has the Apple Events automation entitlement plus usage descriptions in
`Info.plist`.

### Seek reconciliation

`NowPlayingService.seek(to:)`:

1. requires an active provider, a snapshot, a positive duration, and a finite
   target,
2. clamps the target into the track,
3. records a `NowPlayingPendingSeek`,
4. schedules a 2 s cancellation through the injected scheduler,
5. publishes an optimistic snapshot at the target,
6. sends `.seek(target)` to the provider.

While a seek is pending, provider positions more than 1.5 s from the expected
position are ignored. A matching position, a track change, a timeout, a new
seek, a provider reset, or `stop()` clears the pending state. After a timeout,
the next provider position is accepted as real.

## Settings

`SettingsStore` is an `ObservableObject` backed by `UserDefaults`. Current keys:

| Key | Default |
| --- | --- |
| `fineTuneWidth` | 0 |
| `fineTuneHeight` | 0 |
| `topFlareRadius` | 0 |
| `bottomRadius` | 0 |
| `openOnHover` | true |
| `hoverIntentDelay` | 0.0 |
| `closeDelay` | 0.0 |
| `minStateDwell` | 0.0 |
| `verticalGesturesEnabled` | true |
| `hapticsEnabled` | true |
| `mediaCompactEnabled` | true |
| `hotPaddingX` | 14 |
| `hotPaddingBelow` | 4 |
| `flyByGuardEnabled` | false |
| `flyBySpeedThreshold` | 2.5 |
| `slowMotion` | false |
| `hapticPattern` | `generic` |

The Settings window currently contains one Media section with the compact media
activity toggle. The Animation Lab and debug overlay expose the remaining
values in DEBUG builds.

## Build-time integration

The Xcode project has a `Prepare Now Playing Runtime` shell-script phase. It
runs `scripts/prepare-nowplaying-runtime.sh`, which builds the vendored
MediaRemote framework when needed, then copies this into the app resources:

```text
Contents/Resources/NowPlaying/mediaremote-adapter.pl
Contents/Resources/NowPlaying/MediaRemoteAdapter.framework
```

The app is macOS 14.6+, Swift 5 language mode, hardened runtime enabled, App
Sandbox disabled. Debug and Release both use
`BilouNook/BilouNook/BilouNook.entitlements`.

Debug code is compiled behind `#if DEBUG`. Release contains no debug windows,
hotkeys, launch modes, overlay, animation lab, or mouse/seek debug logs.

## Source map

```text
BilouNook/
  BilouNook/
    App/            application entry and delegate
    Animations/     shared motion constants and plans
    Debug/          DEBUG-only tools
    Haptics/        the single haptic service
    Interaction/    mouse, gesture, watchdog, hit regions
    Modules/
      Core/         module protocol, registry, layout, shell
      Media/        media module, layout, views, formatting, transport
      ModuleA/      placeholder module
      ModuleB/      placeholder module
    Notch/          coordinator, root view, shape, geometry, overlays
    NowPlaying/     providers, service, snapshot, live activity state
    Settings/       settings store and window
    State/          notch state machine
    Utils/          screen resolution
    Window/         panel, panel controller, screen attachment
  BilouNookTests/   unit, geometry, state, coordinator, render tests
Vendor/             vendored MediaRemote adapter
scripts/            project checks, runtime build, smoke test, icon helper
docs/               current documentation and historical records
```
