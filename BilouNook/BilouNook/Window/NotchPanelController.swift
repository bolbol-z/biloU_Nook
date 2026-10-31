import AppKit
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
    let panel = NotchPanel()
    private(set) var coordinator: NotchCoordinator?
    private(set) var hostingView: NSHostingView<NotchRootView>?
    private var observerTokens: [NSObjectProtocol] = []

    func show() {
        let coordinator = NotchCoordinator(panel: panel)
        self.coordinator = coordinator
        let hosting = NSHostingView(rootView: NotchRootView(coordinator: coordinator))
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        hostingView = hosting
        panel.orderFrontRegardless()
        startObservers()
        reposition()
    }

    func stop() {
        coordinator?.stop()
        coordinator = nil
        stopObservers()
        panel.orderOut(nil)
        panel.contentView = nil
        hostingView = nil
    }

    func reposition() {
        let screen = ScreenResolver.shared.targetScreen()
        let size = NotchPanel.panelSize()
        let frame = NotchAttachment.panelFrame(
            screenFrame: screen.frame,
            panelSize: size,
            scale: screen.backingScaleFactor
        )
        panel.setFrame(
            screen.backingAlignedRect(frame, options: [.alignAllEdgesNearest]),
            display: true
        )
    }

    private func startObservers() {
        stopObservers()
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observerTokens = [
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            },
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            },
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            },
            workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            },
        ]
    }

    private func stopObservers() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        for token in observerTokens {
            center.removeObserver(token)
            workspace.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    deinit {
        MainActor.assumeIsolated {
            stopObservers()
        }
    }
}
