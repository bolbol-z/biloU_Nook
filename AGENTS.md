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
2. **Protect the core.** Protected core files: `NotchRootView`, the notch window/panel, the state machine, the shape, and the `HapticsService`. Never shrink or rewrite them. New features go in new files under `Modules/<Feature>/` and plug in through ONE registration point (`NotchModule` protocol + `ModuleRegistry`). If a core file must change, keep the diff minimal and report its line count before/after.
3. **One haptic path.** All haptics go through the existing single `HapticsService` (named styles: `click` for open/close, `tick` for scrubbing). Never call `NSHapticFeedbackManager` anywhere else, never fire several taps for one event.
4. **Finish every task.** Build, run all tests, add at least one test for the new code, run a smoke test (launch arg `--smoke-test`: open the notch, close it, exit code 0), commit, tag `v-<task>`.
5. **Render sanity.** Keep a render sanity test: `NotchRootView` in the open state must produce a non-empty view (it must fail if `body` is empty).
6. **Final report.** Report format: (a) files changed with +/- lines, (b) what is VERIFIED by tests, (c) what is UNVERIFIED and needs my eyes, as a numbered manual checklist of at most 6 items.
7. **Two-strike rule.** If something fails twice, stop and report a diagnosis instead of trial and error.

## Architecture (one page)

### Layers
- **App** (`App/BilouNookApp.swift`): `NSApplicationDelegate`, owns the panel, settings window, monitors, hotkeys, animation lab, and the watchdog lifecycle.
- **Window** (`Window/NotchPanel.swift`): borderless `NSPanel`; size derived from `NotchPresets.open` via `panelSize()`.
- **Notch UI** (`Notch/`): `NotchRootView` (SwiftUI), `NotchShape` + `NotchPresets` (geometry presets; `NotchPresets.open` is the only open-size source), `NotchGeometry` (screen → `NotchRect`), `DebugOverlay`.
- **State** (`State/NotchState.swift`): the single state machine (`closed/peek/opening/open/closing`), shared via `NotchState.shared`; injected `NotchClock` + `NotchScheduler` for tests; watchdog confirmation (`watchdogTick`) lives here.
- **Interaction** (`Interaction/`): `MouseMonitor` (enter/leave edges), `GestureMonitor` (vertical swipe), `Watchdog` (0.25s tick that delegates to `NotchState.watchdogTick`), `InteractionRegion` (`ZoneMath` inclusive hit-testing and phase-correct rects).
- **Services** (`Haptics/`, `Utils/`): `HapticsService`, `ScreenResolver`, `HotKeyManager`, `CoordinateSpace`.
- **Settings** (`Settings/`): `SettingsStore` maps `UserDefaults` keys to observable properties.

### Ownership
- `NotchState.shared` owns phase and timing. Views, monitors, and the watchdog are consumers; only `NotchState` mutates phase.
- `BilouNookApp` owns long-lived objects: panel, monitors, hotkeys, watchdog. `Watchdog.shared` is started once from the root view and stopped on terminate.
- `SettingsStore.shared` owns persisted preferences; views mirror relevant values into `NotchState` (for example `hoverIntentDelay → intentDelay`).

### Open/close path
1. Cursor enters the top hot zone → `MouseMonitor` → `enterIntent()` (honors intent delay) → `requestOpen(.hover)`.
2. `requestOpen` ignores already-open, applies the closing dwell guard, cancels pending timers, sets `opening`, then `peek` (only when hover should peek) or `open`; peek promotes to open after 0.1s.
3. Cursor leaves the interactive rect → `requestClose` → `closing` (haptic) → `closed` after `closeDelay`; early closes are rejected until `minStateDwell` has passed.
4. Re-entering during `closing` (after the dwell) cancels the pending close and reopens.
5. `Watchdog` polls the phase-correct rect; after 0.5s continuously outside it calls `closeImmediately(.watchdog)`, which uses the same closing path.

### Settings keys (`SettingsStore`, `UserDefaults`)
`fineTuneWidth`, `fineTuneHeight`, `handlerEnabled`, `handlerWidth`, `handlerHeight`, `displayMode`, `openOnHover`, `hoverIntentDelay`, `closeDelay`, `minStateDwell`, `verticalGesturesEnabled`, `hapticsEnabled`, `mediaCompactEnabled`, `hotPaddingX`, `hotPaddingBelow`, `flyByGuardEnabled`, `flyBySpeedThreshold`, `contentInDelay`, `openHapticPattern`, `closeHapticPattern`, `hapticPattern`, `contentScale_ASSUMPTION`, `contentBlur_ASSUMPTION`, `contentAnchorY_ASSUMPTION`.

## Tests and smoke

- `BilouNookTests` covers `ZoneMath` edges, `NotchGeometry.resolve` formulas, and `NotchState` transitions with a fake clock/scheduler (`xcodebuild test`, Debug, shared scheme). It compiles the pure logic sources directly into the test bundle (no app host), so tests never launch the app.
- `scripts/smoke.sh` builds Debug and runs tests, printing `PASS`/`FAIL`; it never opens the app.

## DEBUG hotkeys and stress

- ⌥⌘D toggles the debug overlay; ⌥⌘L toggles the Animation Lab; ⌥⌘J plays the haptic once (falls back to ⌥⌘K, then ⌥⌘U if registration fails).
- ⌥⌘H is **not** used: it is reserved by macOS (`Hide Others`). The old registration returned `status=0` but the Carbon callback never fired (no `fire id=3`/entry in the hotkeys log), so the haptic shortcut moved to the first free key.
- The Animation Lab "Stress test toggle" button toggles both debug windows 20 times each on the main queue, 50ms apart, and logs `STRESS OK`.

## Vendored code

`third_party/mediaremote-adapter/` is the MediaRemote bridge. It is not linked yet; it will be integrated during the media step.
