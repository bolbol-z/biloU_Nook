#if DEBUG
import SwiftUI
import AppKit
import os.log

final class AnimationLabWindow {
    static let shared = AnimationLabWindow()
    weak var state: NotchState? = NotchState.shared
    private(set) var window: NSWindow?

    func toggle() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            return
        }
        let view = AnimationLabView()
        let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 420, height: 680), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.title = "Animation Lab"
        w.level = .floating
        w.contentView = NSHostingView(rootView: view)
        w.center()
        window = w
        w.makeKeyAndOrderFront(nil)
    }
}

struct AnimationLabView: View {
    @StateObject private var settings = SettingsStore.shared
    @State private var timeScale: Double = 1.0
    @State private var scaleAssume: Double = 0.8
    @State private var blurAssume: Double = 10
    @State private var anchorY: Double = -0.25
    @State private var openHaptic: String = "generic"
    @State private var closeHaptic: String = "generic"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("BilouNook Animation Lab").font(.headline)
                Text("timeScale reset to 1.0 on launch/close (conceptual)").font(.caption)
                Group {
                    Text("Haptics").font(.subheadline)
                    Picker("hapticPattern", selection: $settings.hapticPattern) {
                        Text("generic").tag("generic")
                        Text("alignment").tag("alignment")
                        Text("levelChange").tag("levelChange")
                    }
                    HStack {
                        Button("Play once - generic") { HapticsService.shared.playOnce(.generic) }
                        Button("Play once - alignment") { HapticsService.shared.playOnce(.alignment) }
                        Button("Play once - levelChange") { HapticsService.shared.playOnce(.levelChange) }
                    }
                    Text("haptic calls since last open: \(HapticsService.shared.callsSinceOpen)")
                    Text("haptic calls since last close: \(HapticsService.shared.callsSinceClose)")
                }
                Group {
                    Text("Springs").font(.subheadline)
                    Text("hoverOpen: spring(response:0.58, dampingFraction:0.68)")
                    Text("hoverClose: spring(response:0.58, dampingFraction:0.65)")
                    Text("openFootprint: spring(0.5,0.6)")
                    Text("closeFootprint: spring(0.62,1.0)")
                    Text("contentIn: spring(0.35,1.0).delay(0.1)")
                    Text("contentOut: spring(0.2,1.0)")
                    Text("interactiveSpring(0.15,1.0,0.25), (0.22,0.58,0.25)")
                }
                Group {
                    Text("Content Transition (ASSUMPTION)").font(.subheadline)
                    Slider(value: $scaleAssume, in: 0.5...1.0)
                    Text("scale \(scaleAssume, specifier: "%.2f")")
                    Slider(value: $blurAssume, in: 0...30)
                    Text("blur \(Int(blurAssume))")
                    Slider(value: $anchorY, in: -1.0...0.5)
                    Text("anchorY \(anchorY, specifier: "%.2f")")
                }
                Group {
                    Text("Hot Zone / Dwell").font(.subheadline)
                    Slider(value: $settings.hotPaddingX, in: 0...40)
                    Text("hotPaddingX \(Int(settings.hotPaddingX))")
                    Slider(value: $settings.hotPaddingBelow, in: 0...20)
                    Text("hotPaddingBelow \(Int(settings.hotPaddingBelow))")
                    Slider(value: $settings.minStateDwell, in: 0...0.5)
                    Text("minStateDwell \(settings.minStateDwell, specifier: "%.2f")")
                }
                Button("Copy as Swift (conceptual)") {}
                Button("Stress test toggle") { stressWindows() }
            }
            .padding()
        }
    }

    private func stressWindows() {
        let overlay = DebugOverlayWindow.shared
        let lab = AnimationLabWindow.shared
        for i in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                overlay.toggle()
            }
        }
        for i in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i + 20) * 0.05) {
                lab.toggle()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 40 * 0.05 + 0.05) {
            let log = OSLog(subsystem: "com.bilou.BilouNook", category: "windows")
            os_log(.info, log: log, "STRESS OK overlay_toggles=20 lab_toggles=20")
            print("STRESS OK overlay_toggles=20 lab_toggles=20")
        }
    }
}
#endif
