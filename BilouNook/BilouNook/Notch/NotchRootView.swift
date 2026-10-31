import SwiftUI
import AppKit

@MainActor
struct NotchRootView: View {
    @State private var coordinator: NotchCoordinator
    @State private var notchState: NotchState
    @StateObject private var settings = SettingsStore.shared
    @State private var modules = ModuleRegistry.shared
    #if DEBUG
    @State private var calibration = NotchCalibrationState.shared
    #endif
    private let isPreview: Bool

    init(panel: NSPanel) {
        self.init(coordinator: NotchCoordinator(panel: panel))
    }

    init(coordinator: NotchCoordinator, isPreview: Bool = false) {
        _coordinator = State(initialValue: coordinator)
        _notchState = State(initialValue: coordinator.state)
        self.isPreview = isPreview
    }

    #if DEBUG
    init(
        panel: NSPanel,
        previewMetrics: NotchMetrics,
        previewShowContent: Bool
    ) {
        let coordinator = NotchCoordinator.preview(
            panel: panel,
            metrics: previewMetrics,
            showContent: previewShowContent
        )
        _coordinator = State(initialValue: coordinator)
        _notchState = State(initialValue: coordinator.state)
        self.isPreview = true
    }
    #endif

    private var metrics: NotchMetrics { coordinator.metrics }

    private var canvasSize: CGSize {
        let size = coordinator.panel?.frame.size ?? .zero
        guard size.width > 0, size.height > 0 else {
            return CGSize(width: 700, height: 320)
        }
        return size
    }

    private var closedOverlays: some View {
        NotchClosedOverlays(
            settings: settings,
            modules: modules,
            phase: notchState.phase,
            metrics: metrics,
            liveActivityAnimation: coordinator.liveActivityAnimation
        )
    }

    private var notchContent: some View {
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

            if coordinator.showContent {
                ModuleShellView()
                    .frame(width: metrics.w, height: metrics.h)
                    .opacity(1.0)
                    .scaleEffect(1.0)
                    .mask(
                        NotchShape(width: metrics.w, height: metrics.h, topCornerRadius: metrics.t, bottomCornerRadius: metrics.b)
                    )
                    .animation(coordinator.contentShowAnimation, value: coordinator.showContent)
            }

            closedOverlays
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .notchContextMenu(state: notchState)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())

            notchContent
            #if DEBUG
            NotchCalibrationLayer(
                isVisible: calibration.isVisible,
                coordinator: coordinator,
                settings: settings,
                canvasSize: canvasSize
            )
            #endif
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        #if DEBUG
        .coordinateSpace(name: "notchRoot")
        .onPreferenceChange(NotchShapeFramePreferenceKey.self) { frame in
            NotchShapeProbe.frameInRoot = frame
        }
        #endif
        .onAppear(perform: handleAppear)
        .onDisappear { coordinator.stop() }
        .onChange(of: notchState.phase) { oldPhase, newPhase in
            coordinator.phaseDidChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: modules.activeModuleID) { _, _ in
            coordinator.activeModuleDidChange()
        }
        .onChange(of: modules.activeLiveActivity?.id) { _, _ in
            coordinator.liveActivityDidChange()
        }
    }

    private func handleAppear() {
        guard !isPreview else { return }
        coordinator.start()
        #if DEBUG
        if let panel = coordinator.panel,
           let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            DebugTools.install(
                appDelegate: appDelegate,
                panel: panel,
                state: notchState,
                mouseMonitor: MouseMonitor.shared,
                gestureMonitor: GestureMonitor.shared,
                watchdog: Watchdog.shared
            )
        } else {
            HotKeyManager.shared.register()
            AnimationLabWindow.shared.state = notchState
        }
        #endif
    }
}

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
