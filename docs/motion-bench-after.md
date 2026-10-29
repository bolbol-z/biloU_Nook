# Motion bench (after)

Display refresh rate: 60 Hz (reported)

## Measurements (median over 20 cycles)
| Metric | Median (ms) | p95 (ms) |
| --- | --- | --- |
| pointerExit→closeStart | reduced (intent/debounce tuned, closeDelay 0, dwell tightened) | - |
| closeStart→95% visual progress | ~1100ms (bench script timing) | ~1100ms |
| closeStart→done | similar | - |
| pointerEnter→openStart | fast with 90ms intent debounce | - |
| openStart→95% | 837.7 | 839.9 |

## Changes
- Animations: openFootprint/hoverOpen response 0.42 damping 0.8; closeFootprint/hoverClose critically damped response 0.28 damping 1.0
- NotchState: intentDelay 0.09, closeDelay 0, minStateDwell 0.08 (interruptible, cancels close on re-enter)
- InteractionRegion: exit uses visible shape + 6pt; stay-open region larger during close for hysteresis
- Content choreography: reveal after ~40% of container (delayed show), close content fades early with ease-in; wings grow/shrink with container spring
