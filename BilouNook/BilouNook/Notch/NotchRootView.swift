import SwiftUI
import AppKit

struct NotchRootView: View {
    @State private var notchState = NotchState.shared
    @State private var metrics = NotchMetrics(w: 200, h: 32, t: 6, b: 14)
    @State private var showContent: Bool = false
    @State private var lastOpenTrigger: OpenTrigger = .hover
    @StateObject private var settings = SettingsStore.shared
    @State private var modules = ModuleRegistry.shared
    #if DEBUG
    @State private var calibration = NotchCalibrationState.shared
    #endif
    var panel: NSPanel
    private let isPreview: Bool

    init(panel: NSPanel) {
        self.panel = panel
        self.isPreview = false
    }

    #if DEBUG
    init(
        panel: NSPanel,
        previewMetrics: NotchMetrics,
        previewShowContent: Bool
    ) {
        self.panel = panel
        self.isPreview = true
        _metrics = State(initialValue: previewMetrics)
        _showContent = State(initialValue: previewShowContent)
    }
    #endif

    private var canvasSize: CGSize {
        let size = panel.frame.size
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 700, height: 320)
        }
        return size
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
            
            ZStack(alignment: .top) {
                NotchShape(width: metrics.w, height: metrics.h, topCornerRadius: metrics.t, bottomCornerRadius: metrics.b)
                    .fill(Color.black)
                    #if DEBUG
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: NotchShapeFramePreferenceKey.self,
                                value: proxy.frame(in: .named("notchRoot"))
                            )
                        }
                    }
                    #endif
                    .onTapGesture {
                        notchState.toggle()
                    }
                
            if showContent {
                ModuleShellView()
                    .frame(width: metrics.w, height: metrics.h)
                    .opacity(1.0)
                    .scaleEffect(1.0)
                    .mask(
                        NotchShape(width: metrics.w, height: metrics.h, topCornerRadius: metrics.t, bottomCornerRadius: metrics.b)
                    )
                    .animation(Animations.scaled(Animation.spring(response: 0.32, dampingFraction: 0.9)), value: showContent)
            }

                if notchState.phase == .closed, let compactView = modules.activeModule?.compactView {
                    let screen = ScreenResolver.shared.targetScreen()
                    let geom = NotchGeometry.live(for: screen, settings: settings)
                    let forbidden = geom.forbiddenZone(inShapeSpace: metrics.w)
                    let centerX = metrics.w / 2
                    let compactCenter = CGRect(x: centerX - 6, y: 0, width: 12, height: geom.notchRect.height)
                    let inForbidden = forbidden.intersects(compactCenter)
                    if inForbidden {
                        EmptyView()
                    } else {
                        compactView
                            .frame(width: metrics.w, height: metrics.h)
                            .mask(
                                NotchShape(width: metrics.w, height: metrics.h, topCornerRadius: metrics.t, bottomCornerRadius: metrics.b)
                            )
                            .allowsHitTesting(false)
                    }
                }

                if notchState.phase == .closed, let liveActivity = modules.activeLiveActivity?.liveActivity {
                    liveActivity
                        .frame(width: metrics.w, height: metrics.h)
                        .opacity(0.9)
                        .animation(Animations.scaled(Animation.easeInOut(duration: 0.12)), value: metrics.w)
                        .mask(
                            NotchShape(width: metrics.w, height: metrics.h, topCornerRadius: metrics.t, bottomCornerRadius: metrics.b)
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .contextMenu {
                Button("Settings…") {
                    SettingsWindow.shared.show()
                }
                #if DEBUG
                Button("Animation Lab") { 
                    AnimationLabWindow.shared.state = notchState
                    AnimationLabWindow.shared.toggle()
                }
                Button("Debug overlay") { 
                    DebugOverlayWindow.shared.toggle()
                }
                Button("Haptic test") { 
                    HapticsService.shared.playOnce(.generic)
                }
                #endif
                Button("Quit BilouNook") {
                    NSApplication.shared.terminate(nil)
                }
            }

            #if DEBUG
            if calibration.isVisible {
                let screen = ScreenResolver.shared.targetScreen()
                NotchCalibrationOverlay(
                    geometry: NotchGeometry.live(for: screen, settings: settings),
                    panel: panel
                )
                .frame(width: canvasSize.width, height: canvasSize.height)
            }
            #endif
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        #if DEBUG
        .coordinateSpace(name: "notchRoot")
        .onPreferenceChange(NotchShapeFramePreferenceKey.self) { frame in
            NotchShapeProbe.frameInRoot = frame
        }
        #endif
        .onAppear {
            guard !isPreview else { return }
            let screen = ScreenResolver.shared.targetScreen()
            metrics = closedMetrics(for: screen)
            notchState.openOnHover = settings.openOnHover
            notchState.intentDelay = settings.hoverIntentDelay
            notchState.closeDelay = settings.closeDelay
            notchState.minStateDwell = settings.minStateDwell
            panel.ignoresMouseEvents = true
            #if DEBUG
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                DebugTools.install(appDelegate: appDelegate, panel: panel, state: notchState, mouseMonitor: MouseMonitor.shared, gestureMonitor: GestureMonitor.shared, watchdog: Watchdog.shared)
            } else {
                HotKeyManager.shared.register()
                AnimationLabWindow.shared.state = notchState
            }
            #endif
            setupMonitors()
            Watchdog.shared.start()
            GestureMonitor.shared.start()
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in notchState.closeImmediately(reason: .system) }
        }
        .onChange(of: notchState.phase) { oldPhase, newPhase in
            if newPhase == .open {
                let anim = Animations.hoverOpen
                withAnimation(Animations.scaled(anim)) {
                    metrics = activeOpenMetrics
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if self.notchState.phase == .open {
                        withAnimation(Animations.scaled(Animations.contentIn)) {
                            showContent = true
                        }
                    }
                }
            } else if newPhase == .open {
                withAnimation(Animations.scaled(Animations.hoverOpen)) {
                    let screen = ScreenResolver.shared.targetScreen()
                    metrics = activeOpenMetrics
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if self.notchState.phase == .open || self.notchState.phase == .open {
                        withAnimation(Animations.scaled(Animations.contentIn)) {
                            showContent = true
                        }
                    }
                }
            } else if newPhase == .closed {
                withAnimation(Animations.scaled(Animation.easeIn(duration: 0.12))) {
                    showContent = false
                }
                withAnimation(Animations.scaled(Animations.closeFootprint)) {
                    let screen = ScreenResolver.shared.targetScreen()
                    metrics = closedMetrics(for: screen)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.notchState.phase == .closed {
                        self.panel.ignoresMouseEvents = true
                    }
                }
            }
            updateMouseInteraction()
        }
        .onChange(of: modules.activeModuleID) { _, _ in
            guard notchState.phase == .open else { return }
            withAnimation(Animations.scaled(Animations.hoverOpen)) {
                metrics = activeOpenMetrics
            }
        }
        .onChange(of: modules.activeLiveActivity?.id) { _, _ in
            guard notchState.phase == .closed else { return }
            let screen = ScreenResolver.shared.targetScreen()
            let animation = modules.activeLiveActivity == nil ? Animations.closeFootprint : Animations.openFootprint
            withAnimation(Animations.scaled(animation)) {
                metrics = closedMetrics(for: screen)
            }
        }
        .onChange(of: settings.fineTuneWidth) { _, _ in updateGeometry() }
        .onChange(of: settings.fineTuneHeight) { _, _ in updateGeometry() }
        .onChange(of: settings.topFlareRadius) { _, _ in updateGeometry() }
        .onChange(of: settings.bottomRadius) { _, _ in updateGeometry() }
        .onChange(of: settings.handlerWidth) { _, _ in updateGeometry() }
        .onChange(of: settings.handlerHeight) { _, _ in updateGeometry() }
        .onChange(of: settings.handlerEnabled) { _, _ in updateGeometry() }
        .onChange(of: settings.openOnHover) { _, v in notchState.openOnHover = v }
        .onChange(of: settings.hoverIntentDelay) { _, v in notchState.intentDelay = v }
        .onChange(of: settings.closeDelay) { _, v in notchState.closeDelay = v }
        .onChange(of: settings.minStateDwell) { _, v in notchState.minStateDwell = v }
    }
    
    private var activeOpenMetrics: NotchMetrics {
        let size = modules.activeModule?.preferredSize ?? CGSize(width: NotchPresets.open.w, height: NotchPresets.open.h)
        let screen = ScreenResolver.shared.targetScreen()
        return NotchGeometry.live(for: screen, settings: settings).openMetrics(for: size)
    }

    private func closedMetrics(for screen: NSScreen) -> NotchMetrics {
        NotchGeometry.live(for: screen, settings: settings)
            .closedMetrics(isLiveActivityActive: modules.activeLiveActivity != nil)
    }

    func updateGeometry() {
        if notchState.phase == .closed {
            let screen = ScreenResolver.shared.targetScreen()
            metrics = closedMetrics(for: screen)
        }
    }
    
    func setupMonitors() {
        MouseMonitor.shared.onEnterHotZone = {
            lastOpenTrigger = .hover
            notchState.enterIntent()
        }
        MouseMonitor.shared.onLeaveOpenArea = {
            if notchState.phase == .open {
                notchState.cancelIntent()
                notchState.requestClose(reason: .mouseLeft)
            } else if notchState.phase == .closed || notchState.phase == .open {
                notchState.cancelIntent()
            }
        }
        MouseMonitor.shared.onMouseMove = { _ in
            updateMouseInteraction()
        }
        MouseMonitor.shared.start()
        updateMouseInteraction()
    }
    
    func updateMouseInteraction() {
        let mouse = NSEvent.mouseLocation
        let screen = ScreenResolver.shared.targetScreen()
        let rect = InteractionRegion.interactiveRect(for: notchState.phase, screen: screen, notchGeom: NotchGeometry.live(for: screen))
        panel.ignoresMouseEvents = !rect.contains(mouse)
    }
}

#if DEBUG
extension NotchRootView {
    func testHaptics() {
        HapticsService.shared.testAll()
    }
}
#endif

#if DEBUG
extension NotchRootView {
    func addAssumptionSliders() {}
}
#endif

#if DEBUG
enum NotchShapeProbe {
    static var frameInRoot: CGRect?
}

struct NotchShapeFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
#endif
