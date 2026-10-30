#if DEBUG
import AppKit
import Foundation

enum DebugTools {
    static func install(appDelegate: BilouNookAppDelegate, panel: NotchPanel, state: NotchState, mouseMonitor: MouseMonitor, gestureMonitor: GestureMonitor, watchdog: Watchdog) {
        _ = DebugOverlayController.shared
        HotKeyManager.shared.start()
        _ = AnimationLab.shared
        if let delegate = appDelegate as? NSApplicationDelegate {
            // tools hook via existing singletons
        }
        DebugOverlayController.shared.showIfNeeded()
    }

    static func handleLaunchArgs(_ args: [String]) -> Bool {
        return DebugLaunchModes.handle(args)
    }
}
#endif
