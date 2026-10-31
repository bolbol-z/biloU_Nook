import SwiftUI
import AppKit

@MainActor
struct NotchClosedOverlays: View {
    @ObservedObject var settings: SettingsStore
    let modules: ModuleRegistry
    let phase: NotchPhase
    let metrics: NotchMetrics
    let liveActivityAnimation: Animation

    var body: some View {
        if phase == .closed, let compactView = modules.activeModule?.compactView {
            let screen = ScreenResolver.shared.targetScreen()
            let geom = NotchGeometry.live(for: screen, settings: settings)
            let forbidden = geom.forbiddenZone(inShapeSpace: metrics.w)
            let centerX = metrics.w / 2
            let compactCenter = CGRect(x: centerX - 6, y: 0, width: 12, height: geom.notchRect.height)
            if forbidden.intersects(compactCenter) {
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

        if phase == .closed, let liveActivity = modules.activeLiveActivity?.liveActivity {
            liveActivity
                .frame(width: metrics.w, height: metrics.h)
                .opacity(0.9)
                .animation(liveActivityAnimation, value: metrics.w)
                .mask(
                    NotchShape(width: metrics.w, height: metrics.h, topCornerRadius: metrics.t, bottomCornerRadius: metrics.b)
                )
                .allowsHitTesting(false)
        }
    }
}

struct NotchContextMenuModifier: ViewModifier {
    let state: NotchState

    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Settings…") {
                SettingsWindow.shared.show()
            }
            #if DEBUG
            Button("Animation Lab") {
                AnimationLabWindow.shared.state = state
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
    }
}

extension View {
    func notchContextMenu(state: NotchState) -> some View {
        modifier(NotchContextMenuModifier(state: state))
    }
}

#if DEBUG
@MainActor
struct NotchCalibrationLayer: View {
    let isVisible: Bool
    let coordinator: NotchCoordinator
    @ObservedObject var settings: SettingsStore
    let canvasSize: CGSize

    var body: some View {
        if isVisible, let panel = coordinator.panel {
            let screen = ScreenResolver.shared.targetScreen()
            NotchCalibrationOverlay(
                geometry: NotchGeometry.live(for: screen, settings: settings),
                panel: panel
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }
}
#endif
