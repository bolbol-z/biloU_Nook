import AppKit
import XCTest

private final class RecordingHaptics: HapticPlaying {
    private(set) var kinds: [HapticKind] = []

    func play(_ kind: HapticKind) {
        kinds.append(kind)
    }
}

final class NotchCharacterizationTests: XCTestCase {
    private func makeState(
        clock: NotchClock = SystemNotchClock(),
        scheduler: NotchScheduler = SystemNotchScheduler(),
        haptics: HapticPlaying = HapticsService.shared
    ) -> NotchState {
        NotchState(clock: clock, scheduler: scheduler, haptics: haptics)
    }

    func testScriptedOpenCloseEmitsOpenThenCloseHaptic() {
        let clock = NotchStateTestClock()
        let scheduler = NotchStateTestScheduler()
        let haptics = RecordingHaptics()
        let state = makeState(clock: clock, scheduler: scheduler, haptics: haptics)

        state.requestOpen(trigger: .hover)
        clock.advance(0.2)
        state.requestClose(reason: .mouseLeft)

        XCTAssertEqual(haptics.kinds, [.open, .close])
    }

    func testSettingsValuesControlHoverAndTimingInNotchState() {
        let clock = NotchStateTestClock()
        let scheduler = NotchStateTestScheduler()
        let state = makeState(clock: clock, scheduler: scheduler)

        state.openOnHover = false
        state.intentDelay = 0.1
        state.closeDelay = 0.15
        state.minStateDwell = 0.12

        state.enterIntent()
        scheduler.advance(by: 1.0)
        XCTAssertEqual(state.phase, .closed)

        state.openOnHover = true
        state.enterIntent()
        scheduler.advance(by: 0.1)
        XCTAssertEqual(state.phase, .open)

        clock.advance(0.05)
        state.requestClose(reason: .mouseLeft)
        XCTAssertEqual(state.phase, .open)

        clock.advance(0.08)
        state.requestClose(reason: .mouseLeft)
        XCTAssertEqual(state.phase, .closing)

        scheduler.advance(by: 0.14)
        XCTAssertEqual(state.phase, .closing)
        scheduler.advance(by: 0.01)
        XCTAssertEqual(state.phase, .closed)
    }

    func testClosedAndOpenMetricsComeFromGeometryAndModuleSize() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            backingScaleFactor: 2,
            auxLeft: CGRect(x: 0, y: 924, width: 646, height: 32),
            auxRight: CGRect(x: 825, y: 924, width: 645, height: 32),
            safeAreaTop: 32
        )
        let closed = geometry.closedMetrics(isLiveActivityActive: false)
        let open = geometry.openMetrics(for: CGSize(width: 520, height: 225))

        XCTAssertEqual(closed.w, 180, accuracy: 0.0001)
        XCTAssertEqual(closed.h, 32.5, accuracy: 0.0001)
        XCTAssertEqual(open.w, 520, accuracy: 0.0001)
        XCTAssertEqual(open.h, 225, accuracy: 0.0001)
        XCTAssertEqual(open.t, closed.t, accuracy: 0.0001)
        XCTAssertEqual(open.b, closed.b, accuracy: 0.0001)
    }
}
