import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    static func panelSize() -> NSSize {
        let largest = max(MediaLayout.width, ModuleA().preferredSize.width, ModuleB().preferredSize.width)
        let margin: CGFloat = 24
        return NSSize(width: largest + margin * 2, height: 220)
    }
    
    init() {
        let screen = ScreenResolver.shared.targetScreen()
        let size = Self.panelSize()
        let rect = NotchAttachment.panelFrame(
            screenFrame: screen.frame,
            panelSize: size,
            scale: screen.backingScaleFactor
        )
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
        isMovable = false
        hidesOnDeactivate = false
        canHide = false
        isFloatingPanel = true
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

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
