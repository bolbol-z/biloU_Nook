# Motion baseline (pre-motion)

Recorded from current codebase state.

## Animations.swift
- hoverOpen: Animation.spring(response: 0.58, dampingFraction: 0.68, blendDuration: 0)
- hoverClose: Animation.spring(response: 0.58, dampingFraction: 0.65, blendDuration: 0)
- hoverClosePure: Animation.spring(response: 0.58, dampingFraction: 1.0, blendDuration: 0)
- openFootprint: Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
- closeFootprint: Animation.spring(response: 0.62, dampingFraction: 1.0, blendDuration: 0)
- contentIn: Animation.spring(response: 0.35, dampingFraction: 1.0, blendDuration: 0).delay(0.1)
- contentOut: Animation.spring(response: 0.2, dampingFraction: 1.0, blendDuration: 0)
- scrubFollow: Animation.interactiveSpring(response: 0.15, dampingFraction: 1.0, blendDuration: 0.25)
- scrubDrag: Animation.interactiveSpring(response: 0.22, dampingFraction: 0.58, blendDuration: 0.25)
- timeScale: 1.0

## NotchState defaults
- intentDelay: 0
- closeDelay: 0.15
- openOnHover: true
- minStateDwell: 0.12
- SettingsStore defaults: hoverIntentDelay 0, closeDelay 0.15, minStateDwell 0.12

## Timing paths
- enterIntent() schedules requestOpen after intentDelay (default 0) if not rejected
- requestClose() schedules phase->closed after closeDelay (0.15) via scheduler
- watchdogTick() calls closeImmediately after 0.5s outside

## Exit/hit-testing
- InteractionRegion.interactiveRect depends on phase/screen/notchGeom; uses ZoneMath inclusive hit-testing
- Panel ignores mouse events based on rect.contains(mouse)
