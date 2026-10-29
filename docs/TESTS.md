TESTS - FIX PASS 1
Date: Sat Oct 25 2026

Panel size: maxOpenWidth*1.25+80 x maxOpenHeight*1.25+60 placed flush at top-center. constrainFrameRect returns unchanged. animationBehavior .none, hidesOnDeactivate false, canHide false, isFloatingPanel true, isMovable false, isReleasedWhenClosed false. collectionBehavior includes .ignoresCycle.

ScreenResolver: prefers built-in (CGDisplayIsBuiltin or safeAreaInsets.top>0), else screen under mouse, else NSScreen.main. Re-resolves on didChangeScreenParameters, screensDidWake, didWake, activeSpaceDidChange.

Click-through:
- Start with ignoresMouseEvents = true. Both global and local mouseMoved monitors feed same handler. On every mouse event compute InteractionRegion (closed: notch+6pt h/+3pt above; open: open+12pt margin) and set ignoresMouseEvents = !interactiveRect.contains(mouse). When closing finishes set ignoresMouseEvents true again.
- Test: Click Xcode/Finder menu items and browser tabs located under the transparent 700x320 area -> should reach apps below. Click closed notch -> enters hot zone/interactive region. External display connect/disconnect -> repositions. Lid closed -> uses fallback.

Right-click menu remains; "Settings…" opens placeholder window titled "Settings (step 11)".

CoordinateSpace unit test: 1470x956 screen, mouse at top-center and 1pt below notch - helper provided.

TESTS - FIX PASS 2
Date: Sat Oct 25 2026

SettingsStore (UserDefaults, ObservableObject, injected via environment/StateObject) with keys: fineTuneWidth, fineTuneHeight, handlerEnabled/Width/Height, displayMode, openOnHover, hoverIntentDelay(0.08), closeDelay(0.15), verticalGesturesEnabled, hapticsEnabled. NotchGeometry becomes pure function geometry(for:screen,settings:) computed on demand. Debug stepper in overlay changes shape live.

Debug tools wrapped in #if DEBUG. Removed local-monitor KeyMonitor. Carbon RegisterEventHotKey for ⌥⌘D (overlay), ⌥⌘L (Animation Lab), ⌥⌘H (haptic test) - works while another app frontmost, no Accessibility permission needed. Right-click menu adds Animation Lab, Debug overlay, Haptic test (DEBUG only). Windows use floating level and NSApp.activate(ignoringOtherApps: true).

Tests:
- Hotkeys work with Safari frontmost (⌥⌘D, ⌥⌘L, ⌥⌘H)
- Fine-tune slider/stepper in overlay changes shape instantly without relaunch

TESTS - FIX PASS 3
Date: Sat Oct 25 2026

NotchShape draws in full rect, aligned top-center (origin at rect.midX-w/2, rect.minY-1). Path: move(0,0), quad to (t,t) control (t,0), line to (t,H-b), quad to (t+b,H) control (t,H), line to (W-t-b,H), quad to (W-t,H-b) control (W-t,H), line to (W-t,t), quad to (W,0) control (W-t,0), close. Ears inside w, radii clamped. animatableData nested pair (w,h,t,b). Presets with _ASSUMPTION values tunable in Lab.

Layering: Layer 0 black fill + shadow (fades in when open, radius 10, y 4, opacity <=0.35). Layer 1 content at final open size masked by same animated NotchShape, kept out of notch band. Overdraw 1-2pt above screen edge. Closed shape should be invisible against hardware notch.

Debug overlay draws shape bounding rect and hardware notch rect for comparison.

TESTS - FIX PASS 3 (updated)
Date: Sat Oct 25 2026

NotchShape draws in full rect aligned top-center (origin x = rect.midX-w/2, y = rect.minY). Path: move(0,0); quad to (t,t) control (t,0); line to (t,H-b); quad to (t+b,H) control (t,H); line to (W-t-b,H); quad to (W-t,H-b) control (W-t,H); line to (W-t,t); quad to (W,0) control (W-t,0); close. Ears inside w, radii clamped to <= min(w,h)/2. animatableData nested AnimatablePair (w,h,t,b). Presets: closed(notchW,notchH,6_ASSUMPTION,14_ASSUMPTION), peek, open(480_ASSUMPTION,150_ASSUMPTION,19_ASSUMPTION,24_ASSUMPTION) tunable in Lab.

Layering: Layer 0 black fill + shadow (open only, radius ~10, y 4, opacity <=0.35). Layer 1 content at final open size aligned top-center, inset top = notch height, revealed with .mask(NotchShape same metrics)) so no reflow. Overdraw 1-2pt above screen edge. Closed = invisible against hardware notch; ears align with notch edges.

TESTS - FIX PASS 4
Date: Sat Oct 25 2026

State machine with peek phase (only if openOnHover false), cancellable Tasks with generation tokens, no 20ms hop. Intent cancels on leave before fire. Leave open rect (+12pt from target metrics) starts close delay; re-enter cancels; enter during close reopens immediately. Click closed/peek opens; clicks inside open content never close. Vertical gestures via scrollWheel monitors (global+local), only in interactive rect, threshold 12pt, reset on ended/cancelled, swipe down opens/up closes; horizontal published to stream. Watchdog 0.25s forces close after 0.5s outside while not closed. System notifications trigger close.

Tests: rapid in/out ×30, leave screen while open, sleep/wake, switch Spaces, scroll gesture.
