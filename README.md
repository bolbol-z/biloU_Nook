# BilouNook

BilouNook is a personal macOS notch utility. It draws a notch-anchored panel
that can open on hover or click, hosts small modules, and shows now-playing
information.

This is a personal project, not a published product. It is accurate to the code
in this repository today.

## Requirements

- macOS 14.6 or later (`MACOSX_DEPLOYMENT_TARGET = 14.6`)
- Xcode (open `BilouNook/BilouNook.xcodeproj`)
- The project builds in Debug; Release is not part of this README

## Build

From Xcode:

    open BilouNook/BilouNook.xcodeproj
    # then press Cmd-R

From the command line:

    xcodebuild -project BilouNook/BilouNook.xcodeproj -scheme BilouNook \
      -configuration Debug -derivedDataPath ./build build

## Run

The app is a normal macOS application. Build it, then run it from Xcode with
Cmd-R. It has no Dock icon of its own; it lives in the menu bar.

## Test

    xcodebuild -project BilouNook/BilouNook.xcodeproj -scheme BilouNook \
      -configuration Debug -derivedDataPath ./build \
      -destination 'platform=macOS' test

Or run the wrapper that also checks the project file, builds, and tests:

    ./scripts/smoke.sh

`scripts/smoke.sh` writes its logs to `build/logs/`.

## DEBUG launch flags

These flags are DEBUG-only. Each one exits on its own; none leaves the app
running normally.

- `--smoke-test`: opens the notch, closes it, exits 0 on success.
- `--notch-selfcheck`: opens the notch, runs the geometry self-check, prints
  `SELFCHECK PASS` or `SELFCHECK FAIL`, exits 0 or 1.
- `--notch-attach-diag`: prints closed and open attachment snapshots, exits 0.
- `--motion-bench`: runs the motion benchmark.

Example:

    build/Build/Products/Debug/BilouNook.app/Contents/MacOS/BilouNook --smoke-test

## DEBUG hotkeys

Hotkeys are registered in DEBUG builds:

- `Cmd-Option-D`: toggle the debug overlay.
- `Cmd-Option-L`: toggle the Animation Lab.
- `Cmd-Option-J`: play one haptic. If J cannot be registered it falls back to K,
  then U. H is reserved by macOS (`Hide Others`) and is not used.

## Repository layout

    BilouNook/                 Xcode project and app sources
      BilouNook/
        App/                   NSApplicationDelegate and lifecycle
        Window/                Notch panel
        Notch/                 Notch views, shape, geometry, debug overlay
        State/                 Notch state machine
        Interaction/           Mouse, gesture, watchdog, hit regions
        Modules/               Module protocol, registry, Core, Media, A, B
        NowPlaying/            Now-playing providers and service
        Settings/              SettingsStore and settings window
        Haptics/               HapticsService
        Utils/                 Screen, hotkey, coordinate helpers
        Debug/                 DEBUG-only diagnostics
        Animations/            Motion constants
      BilouNookTests/          Unit and render tests
    Vendor/MediaRemoteAdapter/ Vendored MediaRemote bridge (see VENDOR.md)
    scripts/                   Project check, build, smoke, icon helpers
    docs/                      Documentation index (docs/README.md)

## Notes

- `docs/archive/` holds historical recovery records. The code is authoritative.
- `docs/reference/` holds third-party-derived notes. The repository must stay
  private.
