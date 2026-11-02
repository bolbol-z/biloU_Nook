# Decisions

This file records decisions that are visible in the current code. Historical
reasoning that is not verifiable from the repository is not invented here.

## D1. One panel, width from the active module

**Decision:** Use one borderless `NSPanel`. Its height is fixed at 220 pt. Its
width is the widest enabled module's preferred width plus 48 pt, with a
fallback to `NotchPresets.open` plus 48 pt.

**Why:** The notch UI needs one stable window for hit testing, screen attachment,
and click-through. Module-specific panel widths would multiply lifecycle and
focus problems.

**Consequences:** Adding a very wide module widens the panel before that module
is selected. All modules share one backing window. The fallback exists for an
empty or unavailable registry.

**Files:** `Window/NotchPanel.swift`, `Window/NotchPanelController.swift`,
`Notch/NotchGeometry.swift`.

## D2. Four notch phases, no peek

**Decision:** Model exactly `closed`, `opening`, `open`, and `closing`.
`opening` is instantaneous; `closing` lasts for `closeDelay`.

**Why:** The current UI has no separate peek behavior; the live activity is an
overlay on `closed`. With no distinct state to represent, a `peek` phase would
only add timing and test branches.

**Consequences:** Any future preview behavior must either add a real phase with
tests or stay as a closed-state overlay. Archived documents that mention peek
are historical, not specifications.

**Files:** `State/NotchState.swift`, `Notch/NotchOverlays.swift`.

## D3. Coordinator owns lifecycle adaptation

**Decision:** `NotchCoordinator` is the single `@MainActor` adapter between
AppKit, SwiftUI, monitors, settings, modules, and `NotchState`. The panel
controller creates it; the root view starts and stops it.

**Why:** The root view had accumulated window-adjacent concerns: settings
subscriptions, timers, mouse state, click-through, screen changes, and sleep.
Those concerns are hard to test through SwiftUI alone.

**Consequences:** The coordinator becomes a protected core file. New feature
behavior goes into modules or new helpers; the coordinator only gets wiring
changes. Its construction is injectable for tests. The coordinator holds the
panel weakly, and tests cover that lifetime.

**Files:** `Notch/NotchCoordinator.swift`, `Window/NotchPanelController.swift`,
`Notch/NotchRootView.swift`.

## D4. Module registry is the only registration point

**Decision:** Register modules once in `ModuleRegistry` at app entry:
`MediaModule`, `ModuleA`, `ModuleB`. The registry owns order, enablement, active
module, live-activity priority, and wraparound.

**Why:** Per-module switches in the panel, root view, or coordinator would make
the core grow with every feature and violate the single registration point.

**Consequences:** Module order is registration order. `ModuleA` and `ModuleB`
remain visible placeholders until a real feature replaces them. Disabling all
modules leaves no active module and uses the fallback open size.

**Files:** `Modules/Core/NotchModule.swift`,
`Modules/Core/ModuleRegistry.swift`, `App/BilouNookApp.swift`.

## D5. Panel width and tab placement share geometry

**Decision:** Derive notch metrics from `NotchGeometry`, and place tabs with
pure `ModuleTabLayout` frames. Tabs avoid the hardware notch's forbidden zone;
the layout reduces spacing before shrinking hit targets.

**Why:** Tab placement previously lived partly in view code and partly in
geometry, so frame behavior could not be asserted directly.

**Consequences:** Tab frames are testable for physical notch, virtual notch,
scaled displays, and external displays. An odd module count puts the extra tab
on the left. A single tab uses the center strip when there is no hardware notch.

**Files:** `Modules/Core/ModuleTabLayout.swift`,
`Modules/Core/ModuleShellView.swift`, `Notch/NotchGeometry.swift`.

## D6. Provider abstraction with MediaRemote first

**Decision:** Use a `NowPlayingProvider` protocol. Try
`MediaRemoteNowPlayingProvider` first, then Spotify AppleScript, then Music
AppleScript. Normalize provider output into `NowPlayingSnapshot` and expose
service state through `NowPlayingService`.

**Why:** MediaRemote gives broader player and browser coverage, but it is a
private framework and can be unavailable. AppleScript is a slower fallback with
official automation permissions.

**Consequences:** Provider support depends on macOS. A provider failure falls
through asynchronously. Media control and metadata can have different
availability. The app is not sandboxed and carries the Apple Events entitlement.

**Files:** `NowPlaying/NowPlayingProvider.swift`,
`NowPlaying/MediaRemoteNowPlayingProvider.swift`,
`NowPlaying/AppleScriptNowPlayingProvider.swift`,
`NowPlaying/NowPlayingService.swift`.

## D7. AppleScript uses structured lists

**Decision:** Both AppleScript providers return a six-item list:
`state, position, title, artist, album, duration`. Parse exactly six items and
reject other counts.

**Why:** A pipe-delimited string shifted every field when title or artist
contained a pipe. Structured descriptors avoid delimiter corruption.

**Consequences:** Pipes, newlines, em dashes, CJK, and empty fields are safe.
Spotify duration is converted from milliseconds; Music duration is seconds.
Provider schema changes must update reading and parsing together.

**Files:** `NowPlaying/AppleScriptNowPlayingProvider.swift`,
`BilouNookTests/AppleScriptNowPlayingProviderTests.swift`.

## D8. Source badge resolves the parent application

**Decision:** Prefer `parentApplicationBundleIdentifier` over the helper bundle
ID for source display. Map WebKit GPU/helper IDs to Safari and generic helper
IDs to their main bundle. Fall back to a generic app icon.

**Why:** Browser media arrives as `com.apple.WebKit.GPU` with Safari as the
parent, so showing the helper icon was wrong.

**Consequences:** `trackIdentity` uses the resolved source, so a parent change
can change track identity. Source lookup is cached, including fallback
resolution. No App Sandbox keeps bundle lookup straightforward.

**Files:** `NowPlaying/NowPlayingSnapshot.swift`,
`Modules/Media/SourceAppInfo.swift`, `Modules/Media/MediaView.swift`.

## D9. Seeks are optimistic with a timeout

**Decision:** Clamp the target, publish an optimistic snapshot, send the seek,
and keep a 2 s pending record. Ignore provider positions more than 1.5 s from
the expected position while pending. Clear on confirmation, track change, timeout,
reset, stop, or a newer seek.

**Why:** A silent provider could leave the UI at an optimistic position forever.
A timeout preserves responsiveness without letting a stale position overwrite a
new seek.

**Consequences:** The displayed position can lead actual playback briefly. After
timeout, the next provider position is authoritative. The pending timeout is
injectable for tests.

**Files:** `NowPlaying/NowPlayingService.swift`,
`BilouNookTests/NowPlayingServiceTests.swift`.

## D10. DEBUG code is a separate build boundary

**Decision:** Keep overlays, Animation Lab, hotkeys, launch modes, mouse tracing,
and seek tracing behind `#if DEBUG`. Keep production verification in
`scripts/smoke.sh`, which checks the project, checks tests for tautologies,
builds, and tests.

**Why:** Debug UI and global hotkeys must not exist in Release. Structural
project corruption and hollow assertions had previously gone unnoticed.

**Consequences:** Release must compile without debug symbols or debug files.
`AnimationLab`, `HotKeyManager`, `DebugLaunchModes`, `MediaSeekDebugLog`, and
`MouseLog` are not part of Release. The user runs the app from Xcode; automation
builds but does not launch it.

**Files:** `Debug/`, `Interaction/InteractionRegion.swift`,
`scripts/check-project.py`, `scripts/check-tests.py`, `scripts/smoke.sh`.

## Deferred decisions

These are known open items, not implemented choices:

1. **Visual verification.** The code and tests are not visual approval. Tab
   placement, media time row, browser badge, band background, and no-notch sheet
   height still need a user run.
2. **Private MediaRemote dependency.** The vendored adapter may break on future
   macOS releases. There is no switch-off UI beyond provider fallback.
3. **Swift 6 language mode.** The project stays on Swift 5 language mode. Moving
   to Swift 6 needs a separate concurrency audit.
4. **Release distribution.** There is no notarization or distribution plan.
   Debug and Release share entitlements.
5. **Placeholder modules.** `ModuleA` and `ModuleB` are visible placeholders and
   are intentionally not removed in this cleanup.
6. **Animation Lab labels.** Some timing labels show historical values. The code
   and `docs/MOTION.md` are authoritative.
7. **Motion static constants.** Several shared animations are declared but not
   used in production. Removing them is deferred to avoid changing the frozen
   motion vocabulary.
8. **TCC reset guidance.** Permission recovery is documented, but the exact
   prompt behavior after ad-hoc rebuilds is OS-version-dependent.
9. **Full-screen and multi-display coverage.** The panel attaches to a target
   screen, but full-screen spaces and unusual display arrangements still need
   manual checks.
10. **Open latency.** MotionBench and archived latency notes exist, but no
    current budget is enforced by tests.
