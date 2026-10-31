import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    static func panelSize(registry: ModuleRegistry = .shared) -> NSSize {
        let margin: CGFloat = 24
        let largest = registry.enabledModules.map(\.preferredSize.width).max() ?? NotchPresets.open.w
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


