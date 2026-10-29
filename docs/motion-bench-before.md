# Motion bench (before)

Display refresh rate: 60 Hz (reported)

## Measurements (median over 20 cycles)
| Metric | Median (ms) | p95 (ms) |
| --- | --- | --- |
| pointerExit→closeStart | (measured via bench script approx) ~50-150ms path | - |
| closeStart→95% visual progress | 1100.5 | 1102.1 |
| closeStart→done | ~1100+ | - |
| pointerEnter→openStart | ~0-80ms | - |
| openStart→95% | 836.8 | 839.4 |

## Diagnosis
- Close: uses `requestClose` with `closeDelay = 0.15s` (150ms) before starting close transition; also has `minStateDwell` checks. The close footprint spring is `closeFootprint = Animation.spring(response: 0.62, dampingFraction: 1.0)` which is slow/underdamped in feel. Combined with contentOut timing and asyncAfter chains this gives long close time.
- Exit region: `InteractionRegion.interactiveRect` is based on phase and shape; panel ignores mouse events based on `rect.contains(mouse)`. Transparent canvas margins can extend interaction area - need to constrain to visible shape + 6pt tolerance.
- Debounce/intent: intentDelay default 0 in state but settings can vary; need 80-100ms intent debounce, no extra close delay.
- Animations are not driven by a single animatable timeline in a coordinated way; content timing uses fixed delays.
