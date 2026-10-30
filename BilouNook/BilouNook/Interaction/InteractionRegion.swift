import AppKit

enum ZoneMath {
    static let topExtension: CGFloat = 6

    static func contains(_ rect: NSRect, _ p: NSPoint) -> Bool {
        return p.x >= rect.minX && p.x <= rect.maxX && p.y >= rect.minY && p.y <= rect.maxY
    }

    #if DEBUG
    static func debugSelfCheck() {
        let rect = NSRect(x: 0, y: 0, width: 10, height: 10)
        let onMaxY = contains(rect, NSPoint(x: 5, y: rect.maxY))
        let oneAbove = contains(rect, NSPoint(x: 5, y: rect.maxY + 1))
        MouseLog.write("ZoneMath self-check onMaxY_inside=\(onMaxY ? "PASS" : "FAIL") maxY_plus1_outside=\(oneAbove ? "FAIL" : "PASS")")
    }
    #endif
}

#if DEBUG
enum MouseLog {
    static let path = "/tmp/bilounook_mouse.log"
    private static let queue = DispatchQueue(label: "com.bilou.bilounook.mouselog")

    static func write(_ message: String) {
        let line = String(format: "%.3f ", Date().timeIntervalSince1970) + message + "\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }
}
#endif

enum InteractionRegion {
    static func hotZone(screen: NSScreen, notchGeom: NotchGeometry) -> NSRect {
        let panelTop = screen.frame.maxY
        let notch = notchGeom.closedMetrics(isLiveActivityActive: false)
        let paddingX = CGFloat(SettingsStore.shared.hotPaddingX)
        let paddingBelow = CGFloat(SettingsStore.shared.hotPaddingBelow)
        let width = notch.w + paddingX * 2
        let height = notch.h + paddingBelow + ZoneMath.topExtension
        return NSRect(x: screen.frame.midX - width / 2, y: panelTop - height, width: width, height: height)
    }

    static func interactiveRect(for phase: NotchPhase, screen: NSScreen, notchGeom: NotchGeometry) -> NSRect {
        let panelTop = screen.frame.maxY
        switch phase {
        case .opening, .open:
            let size = ModuleRegistry.shared.activeModule?.preferredSize ?? CGSize(width: NotchPresets.open.w, height: NotchPresets.open.h)
            let width = size.width + 12
            let height = size.height + ZoneMath.topExtension
            return NSRect(x: screen.frame.midX - width / 2, y: panelTop - height, width: width, height: height)
        case .closing:
            let size = ModuleRegistry.shared.activeModule?.preferredSize ?? CGSize(width: NotchPresets.open.w, height: NotchPresets.open.h)
            let width = size.width + 24 // stay-open region slightly larger
            let height = size.height + ZoneMath.topExtension + 12
            return NSRect(x: screen.frame.midX - width / 2, y: panelTop - height, width: width, height: height)
        case .closed:
            let notch = notchGeom.closedMetrics(isLiveActivityActive: false)
            let width = notch.w + 6
            let height = notch.h + ZoneMath.topExtension
            return NSRect(x: screen.frame.midX - width / 2, y: panelTop - height, width: width, height: height)
        }
    }
}
