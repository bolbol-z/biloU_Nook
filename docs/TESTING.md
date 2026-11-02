# Testing

## What the suite covers

The repository currently has 22 test files and 153 `func test...` methods.
The number can change; the source files are authoritative.

The `BilouNookTests` target is a unit-test bundle with no test host. It compiles
the app's production sources directly into the test bundle, except for
`BilouNookApp.swift`. Tests create their own `NSApplication` or use
`ImageRenderer` when a view needs AppKit/SwiftUI. They do not launch the built
app.

| Test file | Covers |
| --- | --- |
| `ZoneMathTests.swift` | Inclusive rectangle edges and hit testing. |
| `NotchGeometryTests.swift` | Hardware notch resolution, virtual notch, presets, pixel snapping, radius clamping, live activity dimensions. |
| `NotchStateTests.swift` | State transitions, timing, generation invalidation, watchdog behavior. |
| `NotchCharacterizationTests.swift` | Scripted open/close haptics, settings-driven timing, geometry-derived metrics, frozen defaults. |
| `NotchCoordinatorTests.swift` | Content reveal/hide, click-through, module resizing, live activity metrics, stop behavior, panel lifetime. |
| `NotchAttachmentTests.swift` | Panel frame attachment and backing alignment. |
| `NotchPanelTests.swift` | Panel style mask, level, lifetime flags, and key/main behavior. |
| `NotchRootViewRenderTests.swift` | Open root view and module shell render non-empty pixels. |
| `ModuleRegistryTests.swift` | Module order, enablement, active module, live activity priority, wraparound. |
| `CompactLayoutTests.swift` | Compact/live-activity and tab layout geometry, notch flanks, hit targets. |
| `LiveActivityLayoutTests.swift` | Compact live-activity metrics. |
| `SettingsStoreTests.swift` | Defaults, persistence, and reset behavior. |
| `NowPlayingServiceTests.swift` | Provider fallback, snapshot normalization, subscriptions, live activity identity, seek reconciliation, and MediaRemote adapter parsing/commands. |
| `AppleScriptNowPlayingProviderTests.swift` | Six-field parsing, state mapping, duration units, empty values. |
| `MediaFormattingTests.swift` | Time and metadata formatting. |
| `MediaViewStateTests.swift` | Empty/error/ready view state. |
| `MediaPlaybackAnchorTests.swift` | Elapsed-time projection and refresh. |
| `MediaLayoutTests.swift` | Media column, title, progress, control, and compact metrics. |
| `MediaTransportTests.swift` | Play/pause/next/previous routing and seek decisions. |
| `MediaSnapshotRenderTests.swift` | Media empty/playing/paused/artwork renders. |
| `SourceAppInfoCacheTests.swift` | Source badge resolution and caching. |
| `ArtworkDecoderTests.swift` | Artwork MIME/type validation and decoding. |

The render rule is explicit: `NotchRootView` in the open phase must produce a
non-empty image. The render test fails if the view produces no visible pixels.

## Fakes and seams

Tests avoid real time and real feedback:

- `NotchStateTestClock`: manual clock.
- `NotchStateTestScheduler`: manually advanced scheduled work.
- `RecordingHaptics` / `CoordinatorRecordingHaptics`: records haptic kinds.
- `CoordinatorTestMouseMonitor`, `CoordinatorTestWatchdog`,
  `CoordinatorTestGestureMonitor`, `CoordinatorTestSleepObserver`: input fakes.
- `FakeNowPlayingProvider`: controllable provider stream.
- `SnapshotProvider`, `ProbeBox`: deterministic media render inputs.
- `SettingsStore` user-defaults suite: isolated preferences per test.

Production has injected clocks, schedulers, screen providers, monitors,
watchdogs, sleep observers, Reduce Motion providers, and `ignoresMouseEvents`
setters for these tests. Do not reach around a seam by mutating global singletons
in a test unless the test restores them.

## Running tests

Full verification, which also checks project structure and tautological
assertions:

```bash
./scripts/smoke.sh
```

That script runs, in order:

1. `python3 scripts/check-project.py`
2. `python3 scripts/check-tests.py`
3. Debug build with `-derivedDataPath ./build`
4. `xcodebuild test` for the `BilouNook` scheme, Debug, macOS destination

Output is summarized as `PROJECT PASS/FAIL`, `TEST QUALITY PASS/FAIL`,
`BUILD PASS/FAIL`, and `TESTS PASS/FAIL`. Full logs go to:

```text
build/logs/smoke-build.log
build/logs/smoke-test.log
```

Tests alone:

```bash
xcodebuild \
  -project BilouNook/BilouNook.xcodeproj \
  -scheme BilouNook \
  -configuration Debug \
  -derivedDataPath ./build \
  -destination 'platform=macOS' \
  test
```

One suite:

```bash
xcodebuild \
  -project BilouNook/BilouNook.xcodeproj \
  -scheme BilouNook \
  -configuration Debug \
  -derivedDataPath ./build \
  -destination 'platform=macOS' \
  -only-testing:BilouNookTests/NotchStateTests \
  test
```

The scheme's tests run without opening the UI. However, the app target is built
and its `Prepare Now Playing Runtime` phase may build the vendored framework, so
the first run can be slower.

## Project checks

`scripts/check-project.py` parses the `.pbxproj` and fails on:

- duplicate object IDs,
- missing file references,
- Swift source files missing from a group,
- group children that do not exist,
- one path referenced by multiple file-reference IDs.

`scripts/check-tests.py` fails on:

- assertions with identical first two arguments,
- constant assertions such as `XCTAssertTrue(true)`.

Do not bypass either check. Do not add `XCTExpectFailure` or `XCTSkip` to make a
failing test pass. As of 2026-11-01 there are no such annotations in the suite.

## Smoke launch mode

The app also has a DEBUG-only smoke mode:

```bash
/path/to/BilouNook.app/Contents/MacOS/BilouNook --smoke-test
```

It opens the notch, verifies `.open`, closes it after 0.2 s, verifies
`.closing`, and exits 0 when `.closed` is reached. Exit codes:

| Code | Meaning |
| ---: | --- |
| 0 | Open and close completed. |
| 2 | State was not open after `open()`. |
| 3 | State was not closing after `close()`. |
| 4 | State did not reach closed after 0.45 s. |
| 5 | Debug mode could not access the panel controller. |

`scripts/smoke.sh` does not launch this mode; it uses the test target. The launch
mode is useful for a manual app-level smoke check after a fresh build.

Other DEBUG launch modes:

- `--motion-bench`
- `--notch-attach-diag`
- `--notch-selfcheck`
- `BILOUNOOK_NOTCH_DEBUG=1` enables the calibration overlay.

## Rules for new tests

1. Add a test for every behavior change.
2. Prefer state/timing assertions over pixel snapshots.
3. Keep render tests as a guard against empty views, not as appearance
   approvals.
4. Use the injected seams instead of sleeping or using real time.
5. Restore any shared singleton or user-defaults value touched by a test.
6. Keep the suite green under Debug and Release.

## Known test limitation

The suite verifies visible pixels, not visual quality. Hover feel, animation
timing, animation reversal, notch attachment on real hardware, and media
playback behavior still require the manual checklist in the final report.
