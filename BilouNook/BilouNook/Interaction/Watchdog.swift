import AppKit

final class Watchdog {
    static let shared = Watchdog()
    private var timer: Timer?
    
    func start() {
        timer?.invalidate()
        let state = NotchState.shared
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak state] _ in
            guard let state else { return }
            let mouse = NSEvent.mouseLocation
            let screen = ScreenResolver.shared.targetScreen()
            let rect = InteractionRegion.interactiveRect(for: state.phase, screen: screen, notchGeom: NotchGeometry.live(for: screen))
            state.watchdogTick(isOutside: !ZoneMath.contains(rect, mouse))
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
