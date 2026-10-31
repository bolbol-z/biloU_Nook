import AppKit
import Combine
import SwiftUI

struct NotchScreen {
    let frame: CGRect
    let backingScaleFactor: CGFloat
    let auxLeft: CGRect?
    let auxRight: CGRect?
    let safeAreaTop: CGFloat
}

protocol ScreenProviding {
    func targetScreen() -> NotchScreen
}

struct SystemScreenProvider: ScreenProviding {
    func targetScreen() -> NotchScreen {
        let screen = ScreenResolver.shared.targetScreen()
        return NotchScreen(
            frame: screen.frame,
            backingScaleFactor: screen.backingScaleFactor,
            auxLeft: screen.auxiliaryTopLeftArea,
            auxRight: screen.auxiliaryTopRightArea,
            safeAreaTop: screen.safeAreaInsets.top
        )
    }
}

protocol MouseMonitoring: AnyObject {
    var onEnterHotZone: (() -> Void)? { get set }
    var onLeaveOpenArea: (() -> Void)? { get set }
    var onMouseMove: ((NSPoint) -> Void)? { get set }
    func start()
    func stop()
}

extension MouseMonitor: MouseMonitoring {}

protocol WatchdogControlling: AnyObject {
    func start()
    func stop()
}

extension Watchdog: WatchdogControlling {}

protocol GestureMonitoring: AnyObject {
    func start()
    func stop()
}

extension GestureMonitor: GestureMonitoring {}

protocol SleepObserving: AnyObject {
    func start(onSleep: @escaping () -> Void)
    func stop()
}

final class WorkspaceSleepObserver: SleepObserving {
    private var token: NSObjectProtocol?

    func start(onSleep: @escaping () -> Void) {
        guard token == nil else { return }
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in onSleep() }
    }

    func stop() {
        if let token {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            self.token = nil
        }
    }

    deinit {
        stop()
    }
}

final class WeakPanelReference {
    weak var value: NSPanel?

    init(_ value: NSPanel?) {
        self.value = value
    }
}

extension NotchGeometry {
    static func live(for screen: NotchScreen, settings: SettingsStore = .shared) -> NotchGeometry {
        NotchGeometry(
            screenFrame: screen.frame,
            backingScaleFactor: screen.backingScaleFactor,
            auxLeft: screen.auxLeft,
            auxRight: screen.auxRight,
            safeAreaTop: screen.safeAreaTop,
            widthDelta: CGFloat(settings.fineTuneWidth),
            heightDelta: CGFloat(settings.fineTuneHeight),
            topFlareRadiusOverride: CGFloat(settings.topFlareRadius),
            bottomRadiusOverride: CGFloat(settings.bottomRadius)
        )
    }
}

@MainActor
@Observable
final class NotchCoordinator {
    let state: NotchState
    let settings: SettingsStore
    let modules: ModuleRegistry

    private(set) var metrics = NotchMetrics(w: 200, h: 32, t: 6, b: 14)
    private(set) var showContent = false
    private(set) var isStarted = false
    private(set) var isReduceMotionEnabled = false

    var panel: NSPanel? { panelReference.value }

    private let panelReference: WeakPanelReference
    private let screenProvider: ScreenProviding
    private let mouseMonitor: MouseMonitoring
    private let watchdog: WatchdogControlling
    private let gestureMonitor: GestureMonitoring
    private let sleepObserver: SleepObserving
    private let scheduler: NotchScheduler
    private let reduceMotionProvider: () -> Bool
    private let ignoresMouseEventsSetter: (Bool) -> Void

    private var settingsCancellable: AnyCancellable?
    private var contentHandle: NotchScheduled?
    private var clickThroughHandle: NotchScheduled?
    private var cachedInteractiveRect: NSRect?
    private var cachedPhase: NotchPhase?
    private var cachedScreenFrame: CGRect?
    private var lastIgnoresMouseEvents: Bool?

    init(
        panel: NSPanel?,
        state: NotchState = .shared,
        settings: SettingsStore = .shared,
        modules: ModuleRegistry = .shared,
        screenProvider: ScreenProviding = SystemScreenProvider(),
        mouseMonitor: MouseMonitoring = MouseMonitor.shared,
        watchdog: WatchdogControlling = Watchdog.shared,
        gestureMonitor: GestureMonitoring = GestureMonitor.shared,
        sleepObserver: SleepObserving = WorkspaceSleepObserver(),
        scheduler: NotchScheduler = SystemNotchScheduler(),
        isReduceMotionEnabled: @escaping () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        },
        ignoresMouseEventsSetter: ((Bool) -> Void)? = nil
    ) {
        let panel = panel
        self.panelReference = WeakPanelReference(panel)
        self.state = state
        self.settings = settings
        self.modules = modules
        self.screenProvider = screenProvider
        self.mouseMonitor = mouseMonitor
        self.watchdog = watchdog
        self.gestureMonitor = gestureMonitor
        self.sleepObserver = sleepObserver
        self.scheduler = scheduler
        self.reduceMotionProvider = isReduceMotionEnabled
        self.ignoresMouseEventsSetter = ignoresMouseEventsSetter ?? { [weak panel] ignores in
            panel?.ignoresMouseEvents = ignores
        }
    }

    static func preview(panel: NSPanel?, metrics: NotchMetrics, showContent: Bool) -> NotchCoordinator {
        let coordinator = NotchCoordinator(panel: panel)
        coordinator.metrics = metrics
        coordinator.showContent = showContent
        return coordinator
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        isReduceMotionEnabled = reduceMotionProvider()
        applySettings()
        let screen = screenProvider.targetScreen()
        switch state.phase {
        case .open, .opening:
            metrics = activeOpenMetrics(for: screen)
            showContent = true
        case .closed, .closing:
            metrics = closedMetrics(for: screen)
            showContent = false
        }
        applyIgnoresMouseEvents(true)
        subscribeToSettings()
        sleepObserver.start { [weak self] in
            self?.state.closeImmediately(reason: .system)
        }
        mouseMonitor.onEnterHotZone = { [weak self] in
            self?.state.enterIntent()
        }
        mouseMonitor.onLeaveOpenArea = { [weak self] in
            guard let self else { return }
            if self.state.phase == .open {
                self.state.cancelIntent()
                self.state.requestClose(reason: .mouseLeft)
            } else if self.state.phase == .closed || self.state.phase == .open {
                self.state.cancelIntent()
            }
        }
        mouseMonitor.onMouseMove = { [weak self] _ in
            self?.updateMouseInteraction()
        }
        mouseMonitor.start()
        updateMouseInteraction()
        watchdog.start()
        gestureMonitor.start()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        mouseMonitor.onEnterHotZone = nil
        mouseMonitor.onLeaveOpenArea = nil
        mouseMonitor.onMouseMove = nil
        mouseMonitor.stop()
        watchdog.stop()
        gestureMonitor.stop()
        sleepObserver.stop()
        settingsCancellable?.cancel()
        settingsCancellable = nil
        contentHandle?.cancel()
        contentHandle = nil
        clickThroughHandle?.cancel()
        clickThroughHandle = nil
    }

    func applySettings() {
        state.openOnHover = settings.openOnHover
        state.intentDelay = settings.hoverIntentDelay
        state.closeDelay = settings.closeDelay
        state.minStateDwell = settings.minStateDwell
        if state.phase == .closed {
            metrics = closedMetrics(for: screenProvider.targetScreen())
        }
        invalidateInteractiveRect()
    }

    func phaseDidChange(from oldPhase: NotchPhase, to newPhase: NotchPhase) {
        guard oldPhase != newPhase else { return }
        if newPhase == .open {
            contentHandle?.cancel()
            clickThroughHandle?.cancel()
            let screen = screenProvider.targetScreen()
            withAnimation(animation(for: .openMetrics)) {
                metrics = activeOpenMetrics(for: screen)
            }
            contentHandle = scheduler.schedule(after: Animations.contentShowDelay) { [weak self] in
                guard let self, self.state.phase == .open else { return }
                withAnimation(self.animation(for: .contentShow)) {
                    self.showContent = true
                }
            }
        } else if newPhase == .closed {
            contentHandle?.cancel()
            contentHandle = nil
            withAnimation(animation(for: .contentHide)) {
                showContent = false
            }
            let screen = screenProvider.targetScreen()
            withAnimation(animation(for: .closeMetrics)) {
                metrics = closedMetrics(for: screen)
            }
            clickThroughHandle?.cancel()
            clickThroughHandle = scheduler.schedule(after: Animations.clickThroughDelay) { [weak self] in
                guard let self, self.state.phase == .closed else { return }
                self.applyIgnoresMouseEvents(true)
            }
        }
        invalidateInteractiveRect()
        updateMouseInteraction()
    }

    func activeModuleDidChange() {
        guard state.phase == .open else { return }
        let screen = screenProvider.targetScreen()
        withAnimation(animation(for: .moduleChange)) {
            metrics = activeOpenMetrics(for: screen)
        }
        invalidateInteractiveRect()
    }

    func liveActivityDidChange() {
        guard state.phase == .closed else { return }
        let screen = screenProvider.targetScreen()
        let transition: NotchMotionTransition = modules.activeLiveActivity == nil ? .closeMetrics : .openMetrics
        withAnimation(animation(for: transition)) {
            metrics = closedMetrics(for: screen)
        }
        invalidateInteractiveRect()
    }

    func updateMouseInteraction() {
        let rect = interactiveRect()
        let mouse = NSEvent.mouseLocation
        let shouldIgnore = !ZoneMath.contains(rect, mouse)
        if shouldIgnore != lastIgnoresMouseEvents {
            applyIgnoresMouseEvents(shouldIgnore)
        }
    }

    func motionPlan(for transition: NotchMotionTransition) -> NotchMotionPlan {
        Animations.plan(for: transition, reduceMotion: isReduceMotionEnabled)
    }

    var contentShowAnimation: Animation {
        animation(for: .contentShow)
    }

    var contentHideAnimation: Animation {
        animation(for: .contentHide)
    }

    var liveActivityAnimation: Animation {
        animation(for: .liveActivity)
    }

    private func animation(for transition: NotchMotionTransition) -> Animation {
        Animations.animation(for: motionPlan(for: transition))
    }

    private func activeOpenMetrics(for screen: NotchScreen) -> NotchMetrics {
        let size = modules.activeModule?.preferredSize
            ?? CGSize(width: NotchPresets.open.w, height: NotchPresets.open.h)
        return NotchGeometry.live(for: screen, settings: settings).openMetrics(for: size)
    }

    private func closedMetrics(for screen: NotchScreen) -> NotchMetrics {
        NotchGeometry.live(for: screen, settings: settings)
            .closedMetrics(isLiveActivityActive: modules.activeLiveActivity != nil)
    }

    private func interactiveRect() -> NSRect {
        let screen = screenProvider.targetScreen()
        if cachedInteractiveRect == nil
            || cachedPhase != state.phase
            || cachedScreenFrame != screen.frame {
            cachedInteractiveRect = InteractionRegion.interactiveRect(
                for: state.phase,
                screenFrame: screen.frame,
                notchGeom: NotchGeometry.live(for: screen, settings: settings)
            )
            cachedPhase = state.phase
            cachedScreenFrame = screen.frame
        }
        return cachedInteractiveRect ?? .zero
    }

    private func invalidateInteractiveRect() {
        cachedInteractiveRect = nil
        cachedPhase = nil
        cachedScreenFrame = nil
    }

    private func applyIgnoresMouseEvents(_ ignores: Bool) {
        lastIgnoresMouseEvents = ignores
        ignoresMouseEventsSetter(ignores)
    }

    private func subscribeToSettings() {
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isStarted else { return }
                self.applySettings()
            }
        }
    }
}
