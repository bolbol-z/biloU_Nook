#if DEBUG
import AppKit

enum DebugTools {
    static func install(
        appDelegate: AppDelegate,
        panel: NSPanel,
        state: NotchState,
        mouseMonitor: MouseMonitor,
        gestureMonitor: GestureMonitor,
        watchdog: Watchdog
    ) {
        _ = appDelegate
        _ = panel
        _ = mouseMonitor
        _ = gestureMonitor
        _ = watchdog
        HotKeyManager.shared.register()
        AnimationLabWindow.shared.state = state
    }
}
#endif
