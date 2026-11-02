# Development

## Requirements

- macOS 14.6 or later.
- Xcode with a macOS SDK. The current environment is Xcode 26.3 (build 17C529)
  on macOS 15.6, Swift 6.2.4.
- Python 3 for the project and test checks.
- No package manager, CocoaPods, or external runtime is required.

The project targets `MACOSX_DEPLOYMENT_TARGET = 14.6`, uses Swift 5 language
mode, enables the hardened runtime, and disables App Sandbox.

## Open and run

```bash
open BilouNook/BilouNook.xcodeproj
```

Run with Cmd-R in Xcode. The app is an agent-style macOS app with no Dock icon.
It creates a borderless panel at the top of the target screen.

Do not run the app as part of an automated task unless the task explicitly asks
for it. UI behavior is verified by the user from Xcode.

## Build

Always keep derived data inside the repository:

```bash
xcodebuild \
  -project BilouNook/BilouNook.xcodeproj \
  -scheme BilouNook \
  -configuration Debug \
  -derivedDataPath ./build \
  build
```

Do not use a global DerivedData path for verification. Build output is:

```text
build/Build/Products/Debug/BilouNook.app
```

Release build:

```bash
xcodebuild \
  -project BilouNook/BilouNook.xcodeproj \
  -scheme BilouNook \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The app is intended to run locally and is not distributed. Release and Debug
both use the same entitlements file.

## Test

```bash
./scripts/smoke.sh
```

The smoke script runs the project checks, test-quality checks, a Debug build,
and the macOS test suite. Logs are in `build/logs/`.

See [TESTING.md](TESTING.md) for test groups, fakes, single-suite commands, and
the DEBUG launch modes.

## First-run permissions

BilouNook uses three macOS integration points:

1. **Global mouse and scroll monitoring.** `MouseMonitor` and `GestureMonitor`
   install global and local `NSEvent` monitors. If hover or scroll stops working
   after a permission change, a rebuild, or a re-sign, quit the app, check
   System Settings > Privacy & Security > Input Monitoring and Accessibility
   for a stale BilouNook entry, remove it, and relaunch. Grant only if macOS
   asks. Global event monitoring behavior is OS/TCC dependent.
2. **Apple Events automation.** The AppleScript fallback controls Music and
   Spotify. The app has the
   `com.apple.security.automation.apple-events` entitlement and usage strings
   for `com.apple.Music` and `com.apple.Spotify` in `Info.plist`. macOS may show
   an automation prompt on the first control action. Allow
   System Settings > Privacy & Security > Automation > BilouNook > Music and
   Spotify.
3. **Trackpad haptics.** Haptics require a Force Touch trackpad and the system
   haptics setting. The app's own toggle is `SettingsStore.hapticsEnabled`.
   Cooldowns still apply when enabled.

The app does not request Screen Recording, Camera, Microphone, or Full Disk
Access.

## Media runtime

Now-playing uses the vendored MediaRemote adapter first and AppleScript second.

The app target's `Prepare Now Playing Runtime` phase runs
`scripts/prepare-nowplaying-runtime.sh`. That script builds the framework if
needed and copies both the Perl adapter and `MediaRemoteAdapter.framework` into:

```text
BilouNook.app/Contents/Resources/NowPlaying/
```

If the framework is missing at runtime:

```bash
./scripts/build-mediaremote-adapter.sh
```

Then rebuild the app. The framework is a universal `arm64`/`x86_64` dynamic
library, ad-hoc signed, with a 14.6 minimum. `Vendor/MediaRemoteAdapter/build/`
is generated and ignored.

The vendored source and update procedure are documented in
`Vendor/MediaRemoteAdapter/VENDOR.md`.

## Where to change things

| Goal | File |
| --- | --- |
| Add a module | `Modules/Core/NotchModule.swift` plus a new `Modules/<Name>/` and one registration in `BilouNookApp.swift`. |
| Change launch/teardown | `App/AppDelegate.swift`, `Window/NotchPanelController.swift`. |
| Change phase or timing | `State/NotchState.swift`. |
| Change interaction hit areas | `Interaction/InteractionRegion.swift`, `ZoneMath`. |
| Change notch geometry | `Notch/NotchGeometry.swift`, `Notch/NotchShape.swift`. |
| Change content reveal/hide or click-through | `Notch/NotchCoordinator.swift`. |
| Change tab placement | `Modules/Core/ModuleTabLayout.swift`, `ModuleShellView.swift`. |
| Change media layout | `Modules/Media/MediaLayout.swift`, views under `Modules/Media/`. |
| Change provider parsing | `NowPlaying/*.swift`. |
| Change a preference | `Settings/SettingsStore.swift`, `SettingsWindow.swift`. |
| Change motion | `Animations/Animations.swift`, `Modules/Media/MediaMotion.swift`. |
| Add a test | `BilouNook/BilouNookTests/`. |

New modules plug in through one registration point. Do not add module-specific
switches to the panel, root view, or coordinator.

## Debugging

### Logs

DEBUG mouse and hit-test trace:

```text
~/Library/Logs/BilouNook/bilounook_mouse.log
```

DEBUG seek trace:

```text
~/Library/Logs/BilouNook/seek.log
```

Haptics and hotkey events use unified logging:

```bash
log stream --predicate 'subsystem == "com.bilou.BilouNook"'
```

The hotkey category is `hotkeys`; haptics use `haptics`.

The mouse log is written by `MouseLog` in `InteractionRegion.swift`, behind
`#if DEBUG`. The seek log is written by `MediaSeekDebugLog.swift`, also
DEBUG-only. Release compiles neither.

### Overlay and Animation Lab

DEBUG hotkeys:

| Shortcut | Action |
| --- | --- |
| Cmd-Option-D | Toggle the debug overlay. |
| Cmd-Option-L | Toggle the Animation Lab. |
| Cmd-Option-J | Play one haptic. Falls back to K, then U if J is unavailable. |
| Cmd-Option-H | Not used; macOS reserves it for Hide Others. |

The Animation Lab is a DEBUG-only window. Its printed timing labels contain
older historical values; read `Animations.swift` for the current constants.

### Hover not opening

1. Confirm `openOnHover` is enabled in Settings.
2. Check `intentDelay`; if it is large, the pointer must stay in the hot zone.
3. Confirm the fly-by guard did not reject a fast entry.
4. Check the screen resolver is targeting the screen under the pointer if
   follow-mouse is selected.
5. Inspect `bilounook_mouse.log` for `HOT ENTER` and `HOT LEAVE`.
6. Check the watchdog did not close immediately because the pointer was outside
   the phase-correct rect.
7. Recheck TCC permissions as described above.

### Click-through or stuck panel

- The panel intentionally ignores mouse events when the pointer is outside the
  interactive rect.
- After a close it waits 0.2 s before restoring click-through if still closed.
- `MouseMonitor` and `Watchdog` both use `InteractionRegion`; if one rect is
  wrong, hover and watchdog behavior diverge. Check `ZoneMath` edges first.
- The watchdog closes after 0.5 s continuously outside. The state dwell can delay
  that close.

### Media not appearing

1. Check the app resources contain `NowPlaying/mediaremote-adapter.pl` and
   `NowPlaying/MediaRemoteAdapter.framework`.
2. Rebuild the adapter and app.
3. Start playback in Spotify, Music, or a browser and wait for the provider
   stream.
4. Check automation permission if controls fail but metadata works.
5. Check `seek.log` for seek confirmation and timeout.
6. MediaRemote is a private framework; browser/player support varies by macOS
   version.

### Haptics

- Haptics fire on accepted open/close transitions. DEBUG manual hotkeys and
  context-menu actions use `playOnce`.
- Same-kind events within 0.25 s are dropped; opposite transitions within 0.12 s
  are dropped.
- A Force Touch trackpad is required.
- `Cmd-Option-J` uses `playOnce` and bypasses transition rate limiting, not the
  master enable setting.

### Stale build artifacts

Use `xcodebuild ... clean` or change the derived data path. Do not delete the
repository or use destructive cleanup commands.

## Repository hygiene

- Find an existing type, key, helper, or view before adding one.
- Extend existing files; do not create parallel copies.
- Keep debug logging, overlays, and launch modes inside `#if DEBUG`.
- Keep every haptic on `HapticsService`.
- Keep `NotchState` as the only phase mutator.
- Create every `NSWindow`/`NSPanel` once, retain it, set
  `isReleasedWhenClosed = false`, and hide it with `orderOut`, never `close()`.
- Do not leave placeholder bodies in production paths.
- Run `./scripts/smoke.sh` before claiming a change is verified.

## Documentation workflow

- Current behavior: `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`,
  `docs/MOTION.md`, `docs/TESTING.md`, `docs/DEVELOPMENT.md`,
  `docs/DECISIONS.md`.
- Historical evidence: `docs/cleanup-log/`.
- Historical designs and recovery records: `docs/archive/` and `docs/specs/`.
  Do not rewrite them as current documentation.
