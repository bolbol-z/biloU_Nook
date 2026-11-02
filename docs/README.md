# Documentation

The code is the source of truth. These files describe the repository as of
2026-11-01.

## Current reference

| File | Contents |
| --- | --- |
| `ARCHITECTURE.md` | Runtime layers, ownership, panel/geometry, interaction, coordinator, modules, now-playing, settings, build integration. |
| `STATE_MACHINE.md` | Notch phases, triggers, timing, watchdog, haptics, interaction rects, teardown. |
| `MOTION.md` | Coordinator plans, timing constants, Reduce Motion, media motion, slow motion. |
| `TESTING.md` | Test groups, fakes, commands, project checks, DEBUG smoke modes. |
| `DEVELOPMENT.md` | Build/run/test, permissions, media runtime, debugging, repository rules. |
| `DECISIONS.md` | Decisions visible in the current code and deferred items. |

## Layout

- `archive/` — historical recovery records and old notes. Not specifications.
- `reference/` — notes derived from third-party software. Private repository only.
- `specs/` — dated design records. Not current specifications.
- `cleanup-log/` — task logs, manifests, and verification records.

## Historical status

`archive/STATE_MACHINE.md`, `archive/TESTS.md`, and `archive/MOTION_NOTES.md`
describe earlier states of the app. They mention phases and APIs that no longer
exist. Use the current files above.
