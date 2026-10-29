# Notch visibility audit (compact-layout)

This audit identifies elements that can render inside the hardware notch zone in closed/open/wings states.
Derived from the physical-notch case on this Mac (1470x956, hardware notch 179x32 at x=646..825, menu-bar window height 36).

## Closed state
| Element | Source | Location/notes | Risk |
| --- | --- | --- | --- |
| Module tab bar | `Modules/Core/ModuleShellView.tabBar` | Centered HStack at top of `ModuleShellView` (`.padding(.top, 8)`, maxWidth infinity) rendered inside open content area; in closed phase `NotchRootView` shows `compactView` or `liveActivity` masked to shape, but tab bar is only shown in open content (`ModuleShellView` in `showContent` path). The tab bar is visible in **open/wings** contexts; in pure closed compact/live-activity states the tab bar is not rendered by ModuleShellView. However on this notch Mac the tab bar sits exactly where the hardware notch is when open. | High (open state) |
| Closed-state active-module icon / compact view | `NotchRootView` lines ~74-90 | `modules.activeModule?.compactView` and `activeLiveActivity?.liveActivity` shown when `notchState.phase == .closed` masked to shape. If the compact icon/label is centered and falls within the notch width band, it can be hidden behind the physical notch on some notch Mac models. | Medium |
| Debug overlays | `NotchCalibrationOverlay`, `DebugOverlayWindow` | Debug-only (`#if DEBUG`); must remain DEBUG-only. | Low (DEBUG) |
| Centered labels | Various | Any centered label in the top band of the open shape can intersect the hardware notch. | Medium |

## Open state
| Element | Source | Location/notes | Risk |
| --- | --- | --- | --- |
| Tab bar (music note, A, B) | `ModuleShellView.tabBar` | Centered strip at top of ModuleShellView (`padding(.top, 8)`). On this Mac centered at x ~735, sitting exactly over hardware notch 179x32 (x 646-825). Invisible and unclickable behind the hardware notch. | **Critical** |
| Media layout top elements | `MediaContentView` / `MediaLayout` | Header/metadata and content start computed via `NotchContentSafeArea.resolve` using `notchHeight + topClearanceGap`; currently `topClearance = max(notchHeight, menuBarHeight) + topClearanceGap`. Must start at `contentTop = notchHeight + 6`. | Medium |
| Other module views (A, B) | Module views | Placeholder modules must fit within safe area without intersecting forbidden zone. | Medium |

## Wings/Live Activity state
| Element | Source | Location/notes | Risk |
| --- | --- | --- | --- |
| Live activity compact view | `NotchRootView` lines ~83-90 | Shown in closed phase masked to shape; centered content may intersect the notch. | Medium |

## Notes
- All coordinates are derived from `NotchGeometry` (hardwareNotchRect/aux areas/safeAreaTop/screenFrame). No hard-coded screen coordinates.
- Fix: move tab bar to flanks split across both sides of the top band; move/hide any element intersecting the forbidden zone.
