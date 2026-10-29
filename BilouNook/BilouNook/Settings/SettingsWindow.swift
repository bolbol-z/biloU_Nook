import SwiftUI
import AppKit

private struct SettingsContentView: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section("Media") {
                Toggle("Show compact media activity", isOn: $settings.mediaCompactEnabled)
                Text("Shows artwork and an animated equalizer beside the notch while media is playing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}

class SettingsWindow {
    static let shared = SettingsWindow()
    var window: NSWindow?
    
    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsContentView()
        let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 420, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.title = "Settings"
        w.contentView = NSHostingView(rootView: view)
        w.makeKeyAndOrderFront(nil)
        self.window = w
    }
}
