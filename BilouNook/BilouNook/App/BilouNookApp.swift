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

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panelController: NotchPanelController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = NotchPanelController()
        panelController?.show()
        #if DEBUG
        if runAttachDiagnosticIfNeeded() { return }
        if runNotchSelfCheckIfNeeded() { return }
        if runSmokeTestIfNeeded() { return }
        if ProcessInfo.processInfo.environment["BILOUNOOK_NOTCH_DEBUG"] == "1" {
            NotchCalibrationState.shared.setVisible(true)
        }
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

    #if DEBUG
    private func runAttachDiagnosticIfNeeded() -> Bool {
        if CommandLine.arguments.contains("--motion-bench") {
            guard let _ = panelController?.panel else { exit(5) }
            Watchdog.shared.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MotionBench.run()
            }
            return true
        }
        guard CommandLine.arguments.contains("--notch-attach-diag") else { return false }
        guard let panel = panelController?.panel else { exit(5) }
        Watchdog.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotchAttachDiagnostics.printSnapshot(label: "closed", panel: panel)
            NotchState.shared.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NotchAttachDiagnostics.printSnapshot(label: "open", panel: panel)
                exit(0)
            }
        }
        return true
    }

    private func runNotchSelfCheckIfNeeded() -> Bool {
        guard CommandLine.arguments.contains("--notch-selfcheck") else { return false }
        guard let panel = panelController?.panel else { exit(5) }
        Watchdog.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NotchState.shared.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let failures = NotchAttachDiagnostics.selfCheckFailures(panel: panel)
                if failures.isEmpty {
                    print("SELFCHECK PASS")
                    fflush(stdout)
                    exit(0)
                }
                print("SELFCHECK FAIL")
                for failure in failures {
                    print(" - \(failure)")
                }
                fflush(stdout)
                exit(1)
            }
        }
        return true
    }

    private func runSmokeTestIfNeeded() -> Bool {
        guard CommandLine.arguments.contains("--smoke-test") else { return false }
        let state = NotchState.shared
        state.open()
        guard state.phase == .open else { exit(2) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            state.close()
            guard state.phase == .closing else { exit(3) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                exit(state.phase == .closed ? 0 : 4)
            }
        }
        return true
    }
    #endif
}
