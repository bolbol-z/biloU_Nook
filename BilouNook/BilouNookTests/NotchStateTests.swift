import XCTest

final class NotchStateTestClock: NotchClock {
    private(set) var current = Date(timeIntervalSince1970: 1_000_000)
    func now() -> Date { current }
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

final class NotchStateTestScheduler: NotchScheduler {
    private final class Item {
        let id: Int
        let deadline: TimeInterval
        let action: () -> Void

        init(id: Int, deadline: TimeInterval, action: @escaping () -> Void) {
            self.id = id
            self.deadline = deadline
            self.action = action
        }
    }

    private var items: [Item] = []
    private var nextID = 0
    private(set) var currentTime: TimeInterval = 0

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> NotchScheduled {
        let item = Item(id: nextID, deadline: currentTime + delay, action: action)
        nextID += 1
        items.append(item)
        let id = item.id
        return NotchScheduled { [weak self] in self?.remove(id) }
    }

    func advance(by seconds: TimeInterval) {
        currentTime += seconds
        while true {
            let due = items
                .filter { $0.deadline <= currentTime }
                .sorted { ($0.deadline, $0.id) < ($1.deadline, $1.id) }
            guard let next = due.first else { break }
            remove(next.id)
            next.action()
        }
    }

    private func remove(_ id: Int) {
        items.removeAll { $0.id == id }
    }
}

final class NotchStateTests: XCTestCase {
    private func makeState() -> (NotchState, NotchStateTestClock, NotchStateTestScheduler) {
        let clock = NotchStateTestClock()
        let scheduler = NotchStateTestScheduler()
        let state = NotchState(clock: clock, scheduler: scheduler)
        state.minStateDwell = 0.12
        state.closeDelay = 0.15
        return (state, clock, scheduler)
    }

    func testOpenIsImmediate() {
        let (state, _, _) = makeState()
        state.requestOpen(trigger: .click)
        XCTAssertEqual(state.phase, .open)
    }

    func testCloseWaitsForCloseDelay() {
        let (state, clock, scheduler) = makeState()
        state.requestOpen(trigger: .click)
        clock.advance(0.2)
        state.requestClose(reason: .mouseLeft)
        XCTAssertEqual(state.phase, .closing)
        scheduler.advance(by: 0.14)
        XCTAssertEqual(state.phase, .closing)
        scheduler.advance(by: 0.02)
        XCTAssertEqual(state.phase, .closed)
    }

    func testDwellRejectsEarlyClose() {
        let (state, clock, _) = makeState()
        state.requestOpen(trigger: .click)
        clock.advance(0.05)
        state.requestClose(reason: .mouseLeft)
        XCTAssertEqual(state.phase, .open)
        clock.advance(0.08)
        state.requestClose(reason: .mouseLeft)
        XCTAssertEqual(state.phase, .closing)
    }

    func testWatchdogConfirmsAfterHalfSecondOutside() {
        let (state, clock, scheduler) = makeState()
        state.requestOpen(trigger: .click)
        clock.advance(0.2)
        state.watchdogTick(isOutside: true)
        XCTAssertEqual(state.phase, .open)
        clock.advance(0.25)
        state.watchdogTick(isOutside: true)
        XCTAssertEqual(state.phase, .open)
        clock.advance(0.24)
        state.watchdogTick(isOutside: true)
        XCTAssertEqual(state.phase, .open)
        clock.advance(0.01)
        state.watchdogTick(isOutside: true)
        XCTAssertEqual(state.phase, .closing)
        scheduler.advance(by: 0.15)
        XCTAssertEqual(state.phase, .closed)
    }

    func testReenteringCancelsPendingClose() {
        let (state, clock, scheduler) = makeState()
        state.requestOpen(trigger: .click)
        clock.advance(0.2)
        state.requestClose(reason: .mouseLeft)
        XCTAssertEqual(state.phase, .closing)
        clock.advance(0.15)
        state.enterIntent()
        XCTAssertEqual(state.phase, .open)
        scheduler.advance(by: 1.0)
        XCTAssertEqual(state.phase, .open)
    }

    func testPeekAdvancesToOpen() {
        let (state, _, scheduler) = makeState()
        state.requestOpen(trigger: .hover)
        XCTAssertEqual(state.phase, .open)
        scheduler.advance(by: 0.2)
        XCTAssertEqual(state.phase, .open)
    }

    func testCloseImmediatelyUsesClosingPath() {
        let (state, clock, scheduler) = makeState()
        state.requestOpen(trigger: .click)
        clock.advance(0.2)
        state.closeImmediately(reason: .programmatic)
        XCTAssertEqual(state.phase, .closing)
        scheduler.advance(by: 0.15)
        XCTAssertEqual(state.phase, .closed)
    }

    func testEnterIntentSchedulesOpenWhenOpenOnHoverIsEnabled() {
        let (state, _, scheduler) = makeState()
        state.openOnHover = true
        state.intentDelay = 0.1
        state.enterIntent()
        XCTAssertEqual(state.phase, .closed)
        scheduler.advance(by: 0.1)
        XCTAssertEqual(state.phase, .open)
    }

    func testEnterIntentDoesNotScheduleOpenWhenOpenOnHoverIsDisabled() {
        let (state, _, scheduler) = makeState()
        state.openOnHover = false
        state.intentDelay = 0.1
        state.enterIntent()
        XCTAssertEqual(state.phase, .closed)
        scheduler.advance(by: 1.0)
        XCTAssertEqual(state.phase, .closed)
    }

    func testClickStillOpensWhenOpenOnHoverIsDisabled() {
        let (state, _, _) = makeState()
        state.openOnHover = false
        state.requestOpen(trigger: .click)
        XCTAssertEqual(state.phase, .open)
    }
}
