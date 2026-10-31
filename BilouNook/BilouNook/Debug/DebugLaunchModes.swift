#if DEBUG
import Foundation
import AppKit

enum DebugLaunchModes {
    static func handle(_ args: [String]) -> Bool {
        if args.contains("--motion-bench") {
            guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                  let panelController = appDelegate.panelController,
                  panelController.panel.contentView != nil else { exit(5) }
            Watchdog.shared.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MotionBench.run()
            }
            return true
        }
        if args.contains("--notch-attach-diag") {
            guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                  let panelController = appDelegate.panelController else { exit(5) }
            let panel = panelController.panel
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
        if args.contains("--notch-selfcheck") {
            guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                  let panelController = appDelegate.panelController else { exit(5) }
            let panel = panelController.panel
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
        if args.contains("--smoke-test") {
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
        if ProcessInfo.processInfo.environment["BILOUNOOK_NOTCH_DEBUG"] == "1" {
            NotchCalibrationState.shared.setVisible(true)
        }
        return false
    }
}
#endif
