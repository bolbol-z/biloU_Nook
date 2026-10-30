# open-latency-before

## Open-side values (FACT, file:line, direction)

| Element | Value | File:line | Direction | Notes |
| --- | --- | --- | --- | --- |
| States | closed, peek, open, opening, closing | `BilouNook/BilouNook/State/NotchState.swift:5-11` | - | - |
| intentDelay | 0.09 | `BilouNook/BilouNook/State/NotchState.swift:70` | OPEN (enterIntent/requestOpen) | Hover intent delay |
| minStateDwell | 0.08 | `BilouNook/BilouNook/State/NotchState.swift:73` | both (guards) | Can delay transitions |
| closeDelay | 0.0 | `BilouNook/BilouNook/State/NotchState.swift:71` | CLOSE | Frozen |
| peek timeout | 0.1s to open | `BilouNook/BilouNook/State/NotchState.swift:111-116` | OPEN path (if !openOnHover) | Peek stage exists |
| open spring (hover) | Animation.spring(response: 0.42, dampingFraction: 0.8) | `BilouNook/BilouNook/Animations/Animations.swift:12-16` | OPEN (container) | Current |
| close spring | Animation.spring(response: 0.28, dampingFraction: 1.0) | `BilouNook/BilouNook/Animations/Animations.swift:18-22` | CLOSE | Frozen |
| contentIn delay | 0.16s | `BilouNook/BilouNook/Notch/NotchRootView.swift:155` | OPEN content reveal | Fixed delay |
| contentIn anim | spring(response:0.32, damping:0.9) | `BilouNook/BilouNook/Notch/NotchRootView.swift:159` | OPEN | After delay |
| contentOut | easeIn(duration:0.12) | `BilouNook/BilouNook/Notch/NotchRootView.swift:186-203` | CLOSE | Before shrink (frozen behavior) |

## Answers
- intentDelay (0.09) delays OPEN (hover intent). Yes.
- minStateDwell (0.08) can delay transitions; peek→open uses a scheduled timeout after entering peek.
- Peek stage exists: if !openOnHover and hover trigger, goes to .peek then to .open after ~0.1s. Duration ~0.1s.
- Content waits for fixed delay (0.16s) after open; not strictly tied to container progress fraction in current code - choreography is time-based.
