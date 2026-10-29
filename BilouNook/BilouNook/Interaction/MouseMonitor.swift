import AppKit

final class MouseMonitor {
    static let shared = MouseMonitor()
    var onEnterHotZone: (() -> Void)?
    var onLeaveOpenArea: (() -> Void)?
    var onMouseMove: ((NSPoint) -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastPoint: NSPoint = .zero
    private var lastTime: Date = .distantPast
    private var wasInHotZone = false
    
    func start() {
        guard globalMonitor == nil && localMonitor == nil else { return }
        #if DEBUG
        ZoneMath.debugSelfCheck()
        #endif
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }
    
    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        wasInHotZone = false
    }
    
    private func handle(_ event: NSEvent? = nil) {
        let mouse = NSEvent.mouseLocation
        onMouseMove?(mouse)
        let now = Date()
        if SettingsStore.shared.flyByGuardEnabled && lastTime != .distantPast {
            let dx = mouse.x - lastPoint.x
            let dy = mouse.y - lastPoint.y
            let dist = sqrt(dx*dx + dy*dy)
            let dt = now.timeIntervalSince(lastTime)
            if dt > 0 && dist / dt > SettingsStore.shared.flyBySpeedThreshold {
                lastPoint = mouse
                lastTime = now
                return
            }
        }
        lastPoint = mouse
        lastTime = now
        let screen = ScreenResolver.shared.targetScreen()
        let hotRect = InteractionRegion.hotZone(screen: screen, notchGeom: NotchGeometry.live(for: screen))
        let inHotZone = ZoneMath.contains(hotRect, mouse)
        if inHotZone && !wasInHotZone {
            wasInHotZone = true
            #if DEBUG
            MouseLog.write(String(format: "HOT ENTER mouse=(%.1f,%.1f) hotZone={{%.1f,%.1f},{%.1f,%.1f}}", mouse.x, mouse.y, hotRect.minX, hotRect.minY, hotRect.width, hotRect.height))
            #endif
            onEnterHotZone?()
        } else if !inHotZone && wasInHotZone {
            wasInHotZone = false
            #if DEBUG
            MouseLog.write(String(format: "HOT LEAVE mouse=(%.1f,%.1f)", mouse.x, mouse.y))
            #endif
        }
        let state = NotchState.shared
        guard state.phase != .closed else { return }
        let leaveRect = InteractionRegion.interactiveRect(for: state.phase, screen: screen, notchGeom: NotchGeometry.live(for: screen))
        if !ZoneMath.contains(leaveRect, mouse) {
            onLeaveOpenArea?()
        }
    }
}
