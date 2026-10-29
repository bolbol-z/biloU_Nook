import AppKit

enum CoordinateSpace {
    static func mouseLocationInScreen(_ screen: NSScreen) -> NSPoint {
        return NSEvent.mouseLocation
    }
    
    static func pointInPanelCoordinates(_ globalPoint: NSPoint, panel: NSPanel) -> NSPoint {
        guard let screen = panel.screen ?? NSScreen.main else { return globalPoint }
        let panelFrame = panel.frame
        let x = globalPoint.x - panelFrame.origin.x
        let y = (screen.frame.maxY - panelFrame.origin.y) - (screen.frame.maxY - globalPoint.y)
        return NSPoint(x: x, y: panelFrame.height - (globalPoint.y - panelFrame.origin.y))
    }
    
    static func unitTest1470x956() -> (mouseTopCenter: Bool, mouseBelowNotch: Bool) {
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 956)
        let mouseTopCenter = NSPoint(x: 735, y: 955)
        let mouseBelowNotch = NSPoint(x: 735, y: 955 - 1)
        let inFrame = screenFrame.contains(mouseTopCenter) && screenFrame.contains(mouseBelowNotch)
        return (inFrame, inFrame)
    }
}
