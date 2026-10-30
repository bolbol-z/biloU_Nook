import AppKit
import SwiftUI

final class NotchPanelController: NSObject {
    let panel = NotchPanel()
    var hostingView: NSHostingView<NotchRootView>?
    
    func show() {
        let root = NotchRootView(panel: panel)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        hostingView = hosting
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reposition), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reposition), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reposition), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        reposition()
    }
    
    @objc func reposition() {
        let screen = ScreenResolver.shared.targetScreen()
        let size = NotchPanel.panelSize()
        let frame = NotchAttachment.panelFrame(
            screenFrame: screen.frame,
            panelSize: size,
            scale: screen.backingScaleFactor
        )
        panel.setFrame(
            screen.backingAlignedRect(frame, options: [.alignAllEdgesNearest]),
            display: true
        )
    }
}
