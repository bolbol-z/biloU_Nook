#if DEBUG
import AppKit
import ObjectiveC.runtime

enum NotchAttachDiagnostics {
    static func snapshot(label: String, panel: NSPanel) -> String {
        let screen = ScreenResolver.shared.targetScreen()
        let screenFrame = screen.frame
        let auxLeft = screen.auxiliaryTopLeftArea
        let auxRight = screen.auxiliaryTopRightArea
        let hardware = NotchAttachment.hardwareNotchRect(
            screenFrame: screenFrame,
            auxLeft: auxLeft,
            auxRight: auxRight,
            safeAreaTop: screen.safeAreaInsets.top
        )
        let shapeFrame = shapeScreenFrame(panel: panel)
        let menuBar = menuBarWindow()

        var lines: [String] = []
        lines.append("ATTACH[\(label)]")
        lines.append("screen.name=\(screen.localizedName)")
        lines.append("screen.frame=\(format(screenFrame))")
        lines.append("screen.visibleFrame=\(format(screen.visibleFrame))")
        lines.append("screen.backingScaleFactor=\(screen.backingScaleFactor)")
        lines.append("screen.safeAreaInsets=top:\(screen.safeAreaInsets.top),left:\(screen.safeAreaInsets.left),bottom:\(screen.safeAreaInsets.bottom),right:\(screen.safeAreaInsets.right)")
        lines.append("screen.auxLeft=\(auxLeft.map(format) ?? "nil")")
        lines.append("screen.auxRight=\(auxRight.map(format) ?? "nil")")
        lines.append("hardwareNotchRect=\(format(hardware))")
        lines.append("panel.frame=\(format(panel.frame))")
        lines.append("panel.levelRaw=\(panel.level.rawValue)")
        lines.append("mainMenuLevelRaw=\(NSWindow.Level.mainMenu.rawValue)")
        lines.append("panel.collectionBehaviorRaw=\(panel.collectionBehavior.rawValue)")
        lines.append("panel.isOpaque=\(panel.isOpaque)")
        lines.append("panel.backgroundColor=\(String(describing: panel.backgroundColor))")
        lines.append("panel.hasShadow=\(panel.hasShadow)")
        lines.append("panel.ignoresMouseEvents=\(panel.ignoresMouseEvents)")
        lines.append("panel.constrainOverride=\(constrainFrameRectIsOverridden())")
        lines.append("panel.hostingSafeArea.top=\(hostingSafeAreaTop(panel))")
        lines.append("shape.rootFrame=\(NotchShapeProbe.frameInRoot.map(format) ?? "nil")")
        lines.append("shape.screenFrame=\(shapeFrame.map(format) ?? "nil")")
        lines.append("shape.screenTop=\(shapeFrame.map { String(format: "%.3f", $0.maxY) } ?? "nil")")
        lines.append("shape.screenWidth=\(shapeFrame.map { String(format: "%.3f", $0.width) } ?? "nil")")
        lines.append("shape.centerDeltaX=\(shapeFrame.map { String(format: "%.3f", $0.midX - screenFrame.midX) } ?? "nil")")
        lines.append("menuBar.owner=\(menuBar?.owner ?? "nil")")
        lines.append("menuBar.name=\(menuBar?.name ?? "nil")")
        lines.append("menuBar.layer=\(menuBar.map { String($0.layer) } ?? "nil")")
        lines.append("menuBar.bounds=\(menuBar.map { format($0.bounds) } ?? "nil")")
        lines.append("panelAboveMenuBar=\(menuBar.map { panel.level.rawValue > $0.layer } ?? false)")
        return lines.joined(separator: "\n")
    }

    static func printSnapshot(label: String, panel: NSPanel) {
        print(snapshot(label: label, panel: panel))
        fflush(stdout)
    }

    static func menuBarLayer() -> Int? {
        menuBarWindow()?.layer
    }

    static func selfCheckFailures(panel: NSPanel) -> [String] {
        let screen = ScreenResolver.shared.targetScreen()
        var failures: [String] = []
        guard let menuLayer = menuBarLayer() else {
            failures.append("menu bar window not found")
            return failures
        }
        if panel.level.rawValue <= menuLayer {
            failures.append("panel level \(panel.level.rawValue) is not above menu bar layer \(menuLayer)")
        }
        if abs(panel.frame.maxY - screen.frame.maxY) > 0.5 {
            failures.append("panel top \(String(format: "%.3f", panel.frame.maxY)) is not screen top")
        }
        guard let shape = shapeScreenFrame(panel: panel), shape.width > 0, shape.height > 0 else {
            failures.append("shape frame is unavailable")
            return failures
        }
        if abs(shape.maxY - screen.frame.maxY) > 0.5 {
            failures.append("shape top \(String(format: "%.3f", shape.maxY)) is not screen top \(String(format: "%.3f", screen.frame.maxY))")
        }
        if abs(shape.midX - screen.frame.midX) > 1 {
            failures.append("shape center is not screen center")
        }
        let hardware = NotchAttachment.hardwareNotchRect(
            screenFrame: screen.frame,
            auxLeft: screen.auxiliaryTopLeftArea,
            auxRight: screen.auxiliaryTopRightArea,
            safeAreaTop: screen.safeAreaInsets.top
        )
        if shape.width + 0.5 < hardware.width {
            failures.append("shape width \(String(format: "%.3f", shape.width)) does not cover hardware notch \(String(format: "%.3f", hardware.width))")
        }
        return failures
    }

    static func shapeScreenFrame(panel: NSPanel) -> CGRect? {
        guard
            let local = NotchShapeProbe.frameInRoot,
            let hosting = panel.contentView
        else {
            return nil
        }
        let inWindow = hosting.convert(local, to: nil)
        return panel.convertToScreen(inWindow)
    }

    private static func hostingSafeAreaTop(_ panel: NSPanel) -> CGFloat {
        guard let hosting = panel.contentView else { return -1 }
        return hosting.safeAreaInsets.top
    }

    private static func constrainFrameRectIsOverridden() -> Bool {
        let selector = #selector(NSWindow.constrainFrameRect(_:to:))
        let panelIMP = class_getMethodImplementation(NotchPanel.self, selector)
        let baseIMP = class_getMethodImplementation(NSPanel.self, selector)
        return panelIMP != baseIMP
    }

    private struct MenuBarWindow {
        let owner: String
        let name: String?
        let layer: Int
        let bounds: CGRect
    }

    private static func menuBarWindow() -> MenuBarWindow? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let candidates = raw.compactMap { entry -> MenuBarWindow? in
            guard
                let owner = entry[kCGWindowOwnerName as String] as? String,
                let layer = entry[kCGWindowLayer as String] as? Int,
                let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else {
                return nil
            }
            return MenuBarWindow(
                owner: owner,
                name: entry[kCGWindowName as String] as? String,
                layer: layer,
                bounds: bounds
            )
        }
        return candidates
            .filter { $0.owner == "Window Server" && $0.bounds.minY <= 0 && $0.bounds.height > 0 }
            .max { $0.layer < $1.layer }
    }

    private static func format(_ rect: CGRect) -> String {
        String(
            format: "x:%.3f y:%.3f w:%.3f h:%.3f minX:%.3f maxX:%.3f minY:%.3f maxY:%.3f",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            rect.minX,
            rect.maxX,
            rect.minY,
            rect.maxY
        )
    }
}
#endif
