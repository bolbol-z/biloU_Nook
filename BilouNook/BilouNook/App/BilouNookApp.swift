import AppKit
import SwiftUI

@main
struct BilouNookApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panelController: NotchPanelController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = NotchPanelController()
        panelController?.show()
        #if DEBUG
        if DebugLaunchModes.handle(CommandLine.arguments) { return }
        #endif
        NowPlayingService.shared.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        #if DEBUG
        if NotchCalibrationState.shared.isVisible {
            NotchCalibrationState.shared.printValues(label: "final")
        }
        #endif
        Watchdog.shared.stop()
        NowPlayingService.shared.stop()
    }
}
