import AppKit
import SwiftUI
import XCTest

private final class CoordinatorRecordingHaptics: HapticPlaying {
    private(set) var kinds: [HapticKind] = []

    func play(_ kind: HapticKind) {
        kinds.append(kind)
    }
}

private final class CoordinatorTestMouseMonitor: MouseMonitoring {
    var onEnterHotZone: (() -> Void)?
    var onLeaveOpenArea: (() -> Void)?
    var onMouseMove: ((NSPoint) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
}

private final class CoordinatorTestWatchdog: WatchdogControlling {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
}

private final class CoordinatorTestGestureMonitor: GestureMonitoring {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
}

private final class CoordinatorTestSleepObserver: SleepObserving {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var onSleep: (() -> Void)?

    func start(onSleep: @escaping () -> Void) {
        startCount += 1
        self.onSleep = onSleep
    }

    func stop() {
        stopCount += 1
        onSleep = nil
    }
}

private final class CoordinatorTestScheduler: NotchScheduler {
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
    private(set) var scheduledDelays: [TimeInterval] = []

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> NotchScheduled {
        scheduledDelays.append(delay)
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

private final class WeakPanel {
    weak var value: NSPanel?

    init(_ value: NSPanel?) {
        self.value = value
    }
}

private struct CoordinatorTestScreenProvider: ScreenProviding {
    let screen = NotchScreen(
        frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        backingScaleFactor: 2,
        auxLeft: CGRect(x: 0, y: 924, width: 646, height: 32),
        auxRight: CGRect(x: 825, y: 924, width: 645, height: 32),
        safeAreaTop: 32
    )

    func targetScreen() -> NotchScreen { screen }
}

private struct CoordinatorTestModule: NotchModule {
    let id: String
    let title: String
    let icon = "circle"
    let preferredSize: CGSize
    var isLiveActivityActive = false
    var liveActivity: AnyView? = nil
    var expandedView: AnyView { AnyView(EmptyView()) }
}

@MainActor
final class NotchCoordinatorTests: XCTestCase {
    private var savedSettings: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        for key in [
            "fineTuneWidth", "fineTuneHeight", "topFlareRadius", "bottomRadius",
            "openOnHover", "hoverIntentDelay", "closeDelay", "minStateDwell",
        ] {
            savedSettings[key] = defaults.object(forKey: key)
        }
        defaults.set(0.0, forKey: "fineTuneWidth")
        defaults.set(0.0, forKey: "fineTuneHeight")
        defaults.set(0.0, forKey: "topFlareRadius")
        defaults.set(0.0, forKey: "bottomRadius")
        defaults.set(true, forKey: "openOnHover")
        defaults.set(0.0, forKey: "hoverIntentDelay")
        defaults.set(0.0, forKey: "closeDelay")
        defaults.set(0.0, forKey: "minStateDwell")
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for key in savedSettings.keys {
            if let value = savedSettings[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    private func makeCoordinator(
        state: NotchState? = nil,
        settings: SettingsStore = SettingsStore(),
        modules: ModuleRegistry = ModuleRegistry(modules: [
            CoordinatorTestModule(id: "one", title: "One", preferredSize: CGSize(width: 520, height: 225))
        ]),
        scheduler: CoordinatorTestScheduler = CoordinatorTestScheduler(),
        reduceMotion: Bool = false,
        interactionValues: @escaping (Bool) -> Void = { _ in }
    ) -> (NotchCoordinator, NotchState, CoordinatorTestScheduler, CoordinatorTestMouseMonitor, CoordinatorTestWatchdog, CoordinatorTestGestureMonitor, CoordinatorTestSleepObserver) {
        let state = state ?? NotchState(
            clock: NotchStateTestClock(),
            scheduler: NotchStateTestScheduler(),
            haptics: CoordinatorRecordingHaptics()
        )
        let mouse = CoordinatorTestMouseMonitor()
        let watchdog = CoordinatorTestWatchdog()
        let gesture = CoordinatorTestGestureMonitor()
        let sleep = CoordinatorTestSleepObserver()
        let coordinator = NotchCoordinator(
            panel: nil,
            state: state,
            settings: settings,
            modules: modules,
            screenProvider: CoordinatorTestScreenProvider(),
            mouseMonitor: mouse,
            watchdog: watchdog,
            gestureMonitor: gesture,
            sleepObserver: sleep,
            scheduler: scheduler,
            isReduceMotionEnabled: { reduceMotion },
            ignoresMouseEventsSetter: interactionValues
        )
        return (coordinator, state, scheduler, mouse, watchdog, gesture, sleep)
    }

    func testStartAndStopAreIdempotentAndDriveEveryMonitor() {
        let (coordinator, _, _, mouse, watchdog, gesture, sleep) = makeCoordinator()

        coordinator.start()
        coordinator.start()
        XCTAssertEqual(mouse.startCount, 1)
        XCTAssertEqual(watchdog.startCount, 1)
        XCTAssertEqual(gesture.startCount, 1)
        XCTAssertEqual(sleep.startCount, 1)
        XCTAssertTrue(coordinator.isStarted)

        coordinator.stop()
        coordinator.stop()
        XCTAssertEqual(mouse.stopCount, 1)
        XCTAssertEqual(watchdog.stopCount, 1)
        XCTAssertEqual(gesture.stopCount, 1)
        XCTAssertEqual(sleep.stopCount, 1)
        XCTAssertFalse(coordinator.isStarted)

        coordinator.start()
        XCTAssertEqual(mouse.startCount, 2)
        XCTAssertEqual(watchdog.startCount, 2)
        XCTAssertEqual(gesture.startCount, 2)
        XCTAssertEqual(sleep.startCount, 2)
    }

    func testStartAppliesSettingsToNotchStateInOnePlace() {
        let settings = SettingsStore()
        settings.openOnHover = false
        settings.hoverIntentDelay = 0.22
        settings.closeDelay = 0.33
        settings.minStateDwell = 0.44
        let (coordinator, state, _, _, _, _, _) = makeCoordinator(settings: settings)

        coordinator.start()

        XCTAssertFalse(state.openOnHover)
        XCTAssertEqual(state.intentDelay, 0.22)
        XCTAssertEqual(state.closeDelay, 0.33)
        XCTAssertEqual(state.minStateDwell, 0.44)
    }

    func testSettingsChangesPropagateAfterStart() {
        let settings = SettingsStore()
        let (coordinator, state, _, _, _, _, _) = makeCoordinator(settings: settings)
        coordinator.start()

        settings.openOnHover = false
        settings.hoverIntentDelay = 0.17
        settings.closeDelay = 0.18
        settings.minStateDwell = 0.19
        let applied = expectation(description: "settings applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { applied.fulfill() }
        wait(for: [applied], timeout: 1)

        XCTAssertFalse(state.openOnHover)
        XCTAssertEqual(state.intentDelay, 0.17)
        XCTAssertEqual(state.closeDelay, 0.18)
        XCTAssertEqual(state.minStateDwell, 0.19)
    }

    func testPhaseChangesProduceOpenAndClosedMetrics() {
        let modules = ModuleRegistry(modules: [
            CoordinatorTestModule(id: "one", title: "One", preferredSize: CGSize(width: 520, height: 225))
        ])
        let (coordinator, state, _, _, _, _, _) = makeCoordinator(modules: modules)
        let screen = CoordinatorTestScreenProvider().screen
        let geometry = NotchGeometry.live(for: screen, settings: coordinator.settings)

        coordinator.start()
        XCTAssertEqual(coordinator.metrics, geometry.closedMetrics(isLiveActivityActive: false))

        state.phase = .open
        coordinator.phaseDidChange(from: .closed, to: .open)
        XCTAssertEqual(coordinator.metrics, geometry.openMetrics(for: CGSize(width: 520, height: 225)))

        state.phase = .closed
        coordinator.phaseDidChange(from: .open, to: .closed)
        XCTAssertEqual(coordinator.metrics, geometry.closedMetrics(isLiveActivityActive: false))
    }

    func testStartSyncsMetricsWhenStateIsAlreadyOpen() {
        let (coordinator, state, _, _, _, _, _) = makeCoordinator()
        let screen = CoordinatorTestScreenProvider().screen
        let geometry = NotchGeometry.live(for: screen, settings: coordinator.settings)
        state.phase = .open

        coordinator.start()

        XCTAssertEqual(coordinator.metrics, geometry.openMetrics(for: CGSize(width: 520, height: 225)))
        XCTAssertTrue(coordinator.showContent)
    }

    func testOpenShowsContentAfterFiftyMillisecondsAndCloseHidesImmediately() {
        let (coordinator, state, scheduler, _, _, _, _) = makeCoordinator()
        coordinator.start()

        state.phase = .open
        coordinator.phaseDidChange(from: .closed, to: .open)
        XCTAssertEqual(scheduler.scheduledDelays.last ?? 0, 0.05, accuracy: 0.0001)
        XCTAssertFalse(coordinator.showContent)
        scheduler.advance(by: 0.049)
        XCTAssertFalse(coordinator.showContent)
        scheduler.advance(by: 0.001)
        XCTAssertTrue(coordinator.showContent)

        state.phase = .closed
        coordinator.phaseDidChange(from: .open, to: .closed)
        XCTAssertFalse(coordinator.showContent)
        XCTAssertEqual(scheduler.scheduledDelays.last ?? 0, 0.2, accuracy: 0.0001)
    }

    func testMouseInteractionOnlyAssignsWhenBooleanChanges() {
        var interactions: [Bool] = []
        let (coordinator, _, _, _, _, _, _) = makeCoordinator(
            interactionValues: { interactions.append($0) }
        )
        coordinator.start()
        interactions.removeAll()

        coordinator.updateMouseInteraction()
        coordinator.updateMouseInteraction()

        XCTAssertTrue(interactions.isEmpty)
    }

    func testCloseEnablesClickThroughAfterTwoHundredMilliseconds() {
        var interactions: [Bool] = []
        let (coordinator, state, scheduler, _, _, _, _) = makeCoordinator(
            interactionValues: { interactions.append($0) }
        )
        coordinator.start()
        state.phase = .open
        coordinator.phaseDidChange(from: .closed, to: .open)
        state.phase = .closed
        coordinator.phaseDidChange(from: .open, to: .closed)
        interactions.removeAll()

        scheduler.advance(by: 0.199)
        XCTAssertTrue(interactions.isEmpty)
        scheduler.advance(by: 0.001)
        XCTAssertEqual(interactions, [true])
    }

    func testScriptedOpenCloseKeepsSingleHapticPerTransition() {
        let haptics = CoordinatorRecordingHaptics()
        let clock = NotchStateTestClock()
        let stateScheduler = NotchStateTestScheduler()
        let state = NotchState(clock: clock, scheduler: stateScheduler, haptics: haptics)
        let (coordinator, _, _, _, _, _, _) = makeCoordinator(state: state)
        coordinator.start()

        state.requestOpen(trigger: .hover)
        clock.advance(0.2)
        state.requestClose(reason: .mouseLeft)

        XCTAssertEqual(haptics.kinds, [.open, .close])
    }

    func testReduceMotionUsesOnlyShortCrossfades() {
        let (coordinator, _, _, _, _, _, _) = makeCoordinator(reduceMotion: true)
        coordinator.start()

        XCTAssertTrue(coordinator.isReduceMotionEnabled)
        for transition in [
            NotchMotionTransition.openMetrics,
            .closeMetrics,
            .contentShow,
            .contentHide,
            .liveActivity,
            .moduleChange,
        ] {
            XCTAssertEqual(coordinator.motionPlan(for: transition), .crossfade(duration: 0.15))
        }
    }

    func testNormalMotionPreservesGoldenTimings() {
        let (coordinator, _, _, _, _, _, _) = makeCoordinator(reduceMotion: false)
        coordinator.start()

        XCTAssertEqual(coordinator.motionPlan(for: .openMetrics), .spring(response: 0.28, dampingFraction: 0.9))
        XCTAssertEqual(coordinator.motionPlan(for: .closeMetrics), .spring(response: 0.28, dampingFraction: 1.0))
        XCTAssertEqual(coordinator.motionPlan(for: .contentShow), .spring(response: 0.32, dampingFraction: 0.9))
        XCTAssertEqual(coordinator.motionPlan(for: .contentHide), .easeIn(duration: 0.12))
        XCTAssertEqual(coordinator.motionPlan(for: .liveActivity), .easeInOut(duration: 0.12))
        XCTAssertEqual(coordinator.motionPlan(for: .moduleChange), .spring(response: 0.28, dampingFraction: 0.9))
        XCTAssertEqual(Animations.contentShowDelay, 0.05)
        XCTAssertEqual(Animations.clickThroughDelay, 0.2)
    }

    func testCoordinatorHoldsPanelWeakly() {
        let weakPanel = WeakPanel(nil)
        var coordinator: NotchCoordinator?

        autoreleasepool {
            var panel: NSPanel? = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 320),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            weakPanel.value = panel
            coordinator = NotchCoordinator(panel: panel, ignoresMouseEventsSetter: { _ in })
            panel = nil
        }

        XCTAssertNotNil(coordinator)
        XCTAssertNil(coordinator?.panel)
        XCTAssertNil(weakPanel.value)
    }

    func testCoordinatorAndRootViewDoNotRetainPanel() {
        let weakPanel = WeakPanel(nil)
        weak var weakCoordinator: NotchCoordinator?

        autoreleasepool {
            var panel: NSPanel? = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 320),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel?.isReleasedWhenClosed = false
            weakPanel.value = panel
            let coordinator = NotchCoordinator(panel: panel)
            weakCoordinator = coordinator
            let view = NotchRootView(coordinator: coordinator)
            let hosting = NSHostingView(rootView: view)
            panel?.contentView = hosting
            panel = nil
        }

        XCTAssertNil(weakCoordinator)
        XCTAssertNil(weakPanel.value)
    }
}
