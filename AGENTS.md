# AGENTS.md — BilouNook

## Non-negotiable rules

1. **Single source of truth.** Grep the repo before creating a type, file, key, or helper. Reuse the existing one; do not add parallel copies.
2. **Extend, don't replace.** Add to existing files and types. Never rewrite or shorten a file to make a change fit.
3. **Debug tooling is DEBUG-only.** Logging, overlays, animation lab, and self-checks live behind `#if DEBUG`. Release must stay silent.
4. **No stubs in live paths.** No `EmptyView()`, placeholder bodies, or disabled features in production views/flows. If something is unfinished, wire it behind an explicit setting and say so.
5. **Status words.** Until the user confirms visually, the only allowed statuses are `BUILD OK` and `VISUAL UNVERIFIED`. Never claim visual success.
6. **Process.** Build only with `-derivedDataPath ./build`. Do not launch the app; the user runs it from Xcode (⌘R). Do not use `ps | grep` or `pgrep -f`. Paste raw output.
7. **One commit per step.** Stage only that step's files, message `Phase1-Pn: ...`, then stop.
8. **Window lifetime.** Every NSWindow/NSPanel created in code must set isReleasedWhenClosed = false, be created once, retained strongly, and toggled with orderOut — never close() a retained window.

## Safety rules (mandatory, override everything else)

1. **Repository boundary.** Run `pwd` and `git rev-parse --show-toplevel` before any file operation; stop if the result is not this repository. Never touch parent or sibling folders.
2. **Forbidden commands.** Never run `rm`, `rmdir`, `find -delete`, `git clean`, `git reset --hard`, `git gc`, `git prune`, or `git worktree remove`.
3. **Safe file operations.** Remove tracked files only with `git rm`. Move tracked files only with `git mv`.
4. **Outside writes.** The only permitted write outside the repository is `git bundle create ~/Backups/BilouNook/<name>.bundle --all`.
5. **Frozen for the whole cleanup.** Motion constants (`Animations.swift`), haptic behavior and cooldowns, and hover/close timing defaults (`intentDelay` 0, `closeDelay` 0, `minStateDwell` 0) must not change.
6. **Cleanup log.** Every cleanup task ends with `docs/cleanup-log/NN-<task>.txt` describing what changed, the commands run, and the results.

## Working rules (mandatory for every task)

1. **Start clean.** At the start of every task, `git status` must be clean; create tag `pre-<task>`.
2. **Protect the core.** Protected core files: `NotchRootView`, the notch window/panel, the state machine, the shape, `NotchCoordinator`, and the `HapticsService`. Never shrink or rewrite them. New features go in new files under `Modules/<Feature>/` and plug in through ONE registration point (`NotchModule` protocol + `ModuleRegistry`). If a core file must change, keep the diff minimal and report its line count before/after.
3. **One haptic path.** All haptics go through the existing single `HapticsService` (`HapticKind.open` for open, `HapticKind.close` for close). Never call `NSHapticFeedbackManager` anywhere else, never fire several taps for one event.
4. **Finish every task.** Build, run all tests, add at least one test for the new code, run a smoke test (launch arg `--smoke-test`: open the notch, close it, exit code 0), commit, tag `v-<task>`.
5. **Render sanity.** Keep a render sanity test: `NotchRootView` in the open state must produce a non-empty view (it must fail if `body` is empty).
6. **Final report.** Report format: (a) files changed with +/- lines, (b) what is VERIFIED by tests, (c) what is UNVERIFIED and needs my eyes, as a numbered manual checklist of at most 6 items.
7. **Two-strike rule.** If something fails twice, stop and report a diagnosis instead of trial and error.

## Architecture (one page)

Current detail lives in `docs/ARCHITECTURE.md`, `docs/STATE_MACHINE.md`,
`docs/MOTION.md`, `docs/TESTING.md`, `docs/DEVELOPMENT.md`, and
`docs/DECISIONS.md`. This section is the short version.

### Layers
- **App** (`App/BilouNookApp.swift`, `App/AppDelegate.swift`): `NSApplication` entry, owns one `NotchPanelController`, starts/stops `NowPlayingService`, and dispatches DEBUG launch modes.
- **Window** (`Window/`): `NotchPanel` is a borderless nonactivating `NSPanel`; `NotchPanelController` owns the panel, coordinator, and hosting view, and handles screen/wake/space repositioning.
- **Notch UI** (`Notch/`): `NotchRootView` (SwiftUI), `NotchShape` + `NotchPresets`, `NotchGeometry` (screen → metrics), `NotchOverlays`, and `NotchCoordinator`.
- **Coordination** (`Notch/NotchCoordinator.swift`): `@MainActor` adapter for settings, monitors, watchdog, sleep, metrics, content reveal/hide, click-through, and motion selection.
- **State** (`State/NotchState.swift`): the single state machine (`closed/opening/open/closing`, no `peek`), shared via `NotchState.shared`; injected `NotchClock`, `NotchScheduler`, and `HapticPlaying` for tests; `watchdogTick` lives here.
- **Interaction** (`Interaction/`): `MouseMonitor` (enter/leave edges, fly-by guard), `GestureMonitor` (vertical and horizontal swipes), `Watchdog` (0.25s tick delegating to `NotchState.watchdogTick`), `InteractionRegion` (`ZoneMath` inclusive hit-testing and phase-correct rects).
- **Modules** (`Modules/`): `NotchModule` contract, `ModuleRegistry`, pure `ModuleTabLayout`, `ModuleShellView`, `MediaModule`, and placeholders `ModuleA`/`ModuleB`.
- **Now Playing** (`NowPlaying/`): `NowPlayingProvider`, `NowPlayingSnapshot`, `NowPlayingService`, `MediaRemoteNowPlayingProvider` (first), and `AppleScriptNowPlayingProvider` (Spotify/Music fallback).
- **Services** (`Haptics/`, `Utils/`, `Debug/`): `HapticsService`, `ScreenResolver`, DEBUG-only `HotKeyManager`, overlay, Animation Lab, launch modes, and diagnostics.
- **Settings** (`Settings/`): `SettingsStore` maps `UserDefaults` keys to observable properties.

### Ownership
- `NotchState.shared` owns phase and timing. Views, monitors, the coordinator, and the watchdog are consumers; only `NotchState` mutates phase.
- `AppDelegate` owns the panel controller and now-playing lifecycle. `NotchPanelController` owns the panel, coordinator, and hosting view. The coordinator owns monitors, watchdog, gestures, sleep observer, settings subscription, and content/click-through timers.
- `Watchdog.shared` is started once through `NotchCoordinator.start()` and stopped by the coordinator and on terminate.
- `SettingsStore.shared` owns persisted preferences; `NotchCoordinator.applySettings()` copies `openOnHover`, `hoverIntentDelay`, `closeDelay`, and `minStateDwell` into `NotchState`.
- `ModuleRegistry.shared` owns module order, enablement, active module, and live-activity priority. Modules are registered once in `BilouNookApp`.

### Panel size
- Height is fixed at 220 pt.
- Width is the widest enabled module's preferred width + 48 pt.
- Fallback width is `NotchPresets.open` width + 48 pt.
- `NotchGeometry` owns notch resolution, virtual notch fallback, pixel snapping, radius clamping, and open/closed metrics.

### Open/close path
1. Cursor enters the hot zone → `MouseMonitor` → `NotchState.enterIntent()` (honors `openOnHover` and intent delay) → `requestOpen(.hover)`.
2. `requestOpen` ignores `open`/`opening`, applies the closing dwell guard, cancels pending timers, fires one open haptic, sets `opening`, then `open`.
3. Pointer leaves the phase-correct rect while open → `requestClose(.mouseLeft)` → `closing` + one close haptic → `closed` after `closeDelay`; early closes are rejected until `minStateDwell` has passed.
4. Re-entering during `closing` after the dwell cancels the pending close and reopens.
5. `Watchdog` checks the phase-correct rect; after 0.5s continuously outside it calls `closeImmediately(.watchdog)`, which delegates to the same `requestClose` path.
6. `NotchCoordinator` reveals content 0.05s after `open` if still open, hides it on `closed`, and restores click-through 0.2s after `closed` if still closed.

### Now-playing path
1. `NowPlayingService` tries `MediaRemoteNowPlayingProvider` (`perl` + vendored framework/script).
2. It falls back to AppleScript Spotify, then AppleScript Music.
3. Providers produce `NowPlayingSnapshot`; the service normalizes it, resolves the source badge through the parent bundle ID, and exposes live-activity state.
4. Transport commands go through the active provider. Seeks are optimistic, clamped, and reconciled with a 2s timeout.

### Settings keys (`SettingsStore`, `UserDefaults`)
`fineTuneWidth`, `fineTuneHeight`, `topFlareRadius`, `bottomRadius`, `openOnHover`, `hoverIntentDelay`, `closeDelay`, `minStateDwell`, `verticalGesturesEnabled`, `hapticsEnabled`, `mediaCompactEnabled`, `hotPaddingX`, `hotPaddingBelow`, `flyByGuardEnabled`, `flyBySpeedThreshold`, `slowMotion`, `hapticPattern`.

## Tests and smoke

- `BilouNookTests` is a unit-test bundle with no app host. It compiles the app's production sources directly into the test bundle (except `BilouNookApp.swift`), so tests never launch the app.
- Current coverage: 22 test files and 153 test methods, including `ZoneMath`, `NotchGeometry`, `NotchState`, `NotchCoordinator`, panel lifetime, tab layout, module registry, render sanity, now-playing providers/seek, media layout/transport, and settings.
- `scripts/smoke.sh` runs `check-project.py`, `check-tests.py`, a Debug build with `-derivedDataPath ./build`, then `xcodebuild test`. Logs: `build/logs/smoke-build.log`, `build/logs/smoke-test.log`.
- The app has DEBUG launch args (`--smoke-test`, `--notch-selfcheck`, `--notch-attach-diag`, `--motion-bench`), but `scripts/smoke.sh` does not launch the app.

## DEBUG hotkeys and stress

- ⌥⌘D toggles the debug overlay; ⌥⌘L toggles the Animation Lab; ⌥⌘J plays the haptic once (falls back to ⌥⌘K, then ⌥⌘U if registration fails).
- ⌥⌘H is **not** used: it is reserved by macOS (`Hide Others`). The old registration returned `status=0` but the Carbon callback never fired (no `fire id=3`/entry in the hotkeys log), so the haptic shortcut moved to the first free key.
- The Animation Lab "Stress test toggle" button toggles both debug windows 20 times each on the main queue, 50ms apart, and logs `STRESS OK`.
- The Animation Lab's timing labels contain historical values; `Animations.swift` and `docs/MOTION.md` are authoritative.

## Vendored code

`Vendor/MediaRemoteAdapter/` is the vendored MediaRemote bridge, pinned at upstream commit `0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd` (BSD-3-Clause). It is integrated through `scripts/build-mediaremote-adapter.sh` and `scripts/prepare-nowplaying-runtime.sh`, which copy the Perl CLI and framework into app resources at `NowPlaying/`. See `Vendor/MediaRemoteAdapter/VENDOR.md`.
