STATE_MACHINE
Date: Sat Oct 25 2026

Phases: closed, peek (only if openOnHover == false), open

Transitions:
- closed + mouse enters hot zone + openOnHover true: intent timer (hoverIntentDelay 0.08s) -> requestOpen(.hover) -> open (no peek)
- closed + mouse enters hot zone + openOnHover false: intent timer -> peek, then open or stay per rules
- leave hot zone before intent fires: cancel intent
- open + mouse leaves interactive rect (+12pt, target metrics): close after closeDelay 0.15s; re-enter cancels; enter during close reopens immediately (retarget)
- click closed/peek -> open; clicks inside open content never close
- vertical gestures while in interactive rect (scrollWheel global+local): swipe down opens, swipe up closes; threshold ~12pt accumulated; fire once per gesture; reset on ended/cancelled
- horizontal deltas published to NotchGestureEvent stream (no action yet)

Stuck protection: watchdog 0.25s while phase!=closed; if mouse outside interactive rect for 0.5s -> force close; also force close on willSleep/didWake/screensDidWake/activeSpaceDidChange/didChangeScreenParameters

Exactly one pending action at a time via cancellable Task with generation token.
