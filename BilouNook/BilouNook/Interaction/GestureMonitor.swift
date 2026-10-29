import AppKit
import Combine

struct NotchGestureEvent {
    let deltaY: CGFloat
    let deltaX: CGFloat
    let phase: String
}

final class GestureMonitor {
    static let shared = GestureMonitor()
    var gestureStream = PassthroughSubject<NotchGestureEvent, Never>()
    var onHorizontalSwipe: ((Int) -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var accumulated: CGFloat = 0
    private var accumulatedX: CGFloat = 0
    private var horizontalConsumed = false
    private var inGesture = false
    
    func start() {
        guard globalMonitor == nil && localMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }
    
    private func handle(_ event: NSEvent) {
        if !SettingsStore.shared.verticalGesturesEnabled { return }
        let mouse = NSEvent.mouseLocation
        let screen = ScreenResolver.shared.targetScreen()
        let state = NotchState.shared
        let interactiveRect = InteractionRegion.interactiveRect(for: state.phase, screen: screen, notchGeom: NotchGeometry.live(for: screen))
        let hotRect = InteractionRegion.hotZone(screen: screen, notchGeom: NotchGeometry.live(for: screen))
        if !ZoneMath.contains(interactiveRect, mouse) && !ZoneMath.contains(hotRect, mouse) { return }
        let deltaY = event.scrollingDeltaY
        let deltaX = event.scrollingDeltaX
        gestureStream.send(NotchGestureEvent(deltaY: deltaY, deltaX: deltaX, phase: event.phase == .ended ? "ended" : event.phase == .cancelled ? "cancelled" : "changed"))
        if event.phase == .ended || event.phase == .cancelled {
            accumulated = 0
            accumulatedX = 0
            horizontalConsumed = false
            inGesture = false
            return
        }
        if abs(deltaX) > abs(deltaY) {
            guard state.phase == .open, !horizontalConsumed else { return }
            accumulatedX += deltaX
            if abs(accumulatedX) >= 24 {
                onHorizontalSwipe?(accumulatedX < 0 ? 1 : -1)
                accumulatedX = 0
                horizontalConsumed = true
            }
            return
        }
        accumulated += deltaY
        if abs(accumulated) >= 12 {
            if accumulated < 0 {
                state.requestOpen(trigger: .gesture)
            } else if accumulated > 0 {
                state.requestClose(reason: .gesture)
            }
            accumulated = 0
        }
    }
}
