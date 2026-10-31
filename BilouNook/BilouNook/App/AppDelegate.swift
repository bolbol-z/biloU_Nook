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
        panelController?.stop()
        Watchdog.shared.stop()
        NowPlayingService.shared.stop()
    }
}
