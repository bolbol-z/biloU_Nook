import SwiftUI

struct ModuleShellView: View {
    @State private var registry = ModuleRegistry.shared
    @State private var notchState = NotchState.shared

    var body: some View {
        shell
    }

    private var shell: some View {
        ZStack(alignment: .top) {
            tabContent
            moduleTabBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            GestureMonitor.shared.onHorizontalSwipe = { direction in
                switchModules(direction)
            }
        }
        .onDisappear {
            GestureMonitor.shared.onHorizontalSwipe = nil
        }
    }

    private var tabContent: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var geometry: NotchGeometry {
        let screen = ScreenResolver.shared.targetScreen()
        return NotchGeometry.live(for: screen)
    }

    private var moduleTabLayout: ModuleTabLayout {
        let shapeWidth = registry.activeModule?.preferredSize.width ?? NotchPresets.open.w
        return ModuleTabLayout(
            shapeWidth: shapeWidth,
            geometry: geometry,
            moduleCount: registry.enabledModules.count
        )
    }

    private var moduleTabBar: some View {
        let modules = registry.enabledModules
        let layout = moduleTabLayout
        return ZStack(alignment: .topLeading) {
            ForEach(Array(modules.enumerated()), id: \.element.id) { index, module in
                if layout.frames.indices.contains(index) {
                    let frame = layout.frames[index]
                    tabButton(module: module, hitSize: frame.width, iconSize: 14)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(true)
    }

    private func tabButton(module: any NotchModule, hitSize: CGFloat, iconSize: CGFloat) -> some View {
        Button {
            select(module)
        } label: {
            Image(systemName: module.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(module.id == registry.activeModuleID ? Color.white : Color.white.opacity(0.5))
                .frame(width: hitSize, height: hitSize)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(module.id == registry.activeModuleID ? 0.16 : 0))
                )
        }
        .buttonStyle(.plain)
        .help(module.title)
        .frame(width: hitSize, height: hitSize)
        .contentShape(Rectangle())
    }

    private var content: some View {
        ZStack {
            if let module = registry.activeModule {
                module.expandedView
                    .id(module.id)
                    .transition(moduleTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var moduleTransition: AnyTransition {
        let offset = CGFloat(registry.transitionDirection) * 18
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: offset)),
            removal: .opacity.combined(with: .offset(x: -offset))
        )
    }

    private func select(_ module: any NotchModule) {
        guard module.id != registry.activeModuleID else { return }
        withAnimation(Animations.scaled(Animations.contentOut)) {
            registry.select(id: module.id)
        }
    }

    private func switchModules(_ direction: Int) {
        withAnimation(Animations.scaled(Animations.contentOut)) {
            if direction > 0 {
                registry.selectNext()
            } else {
                registry.selectPrevious()
            }
        }
    }
}
