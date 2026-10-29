import SwiftUI

struct ModuleShellView: View {
    @State private var registry = ModuleRegistry.shared
    @State private var notchState = NotchState.shared

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                tabBarSpacer
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            flankTabBar
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

    private var geometry: NotchGeometry {
        let screen = ScreenResolver.shared.targetScreen()
        return NotchGeometry.live(for: screen)
    }

    private var tabBarSpacer: some View {
        Color.clear
            .frame(height: geometry.notchRect.height)
    }

    private var notchHeight: CGFloat {
        geometry.notchRect.height
    }

    private var hasNotch: Bool {
        geometry.isPhysicalNotch
    }

    private var flankTabBar: some View {
        let modules = registry.enabledModules
        let leftCount = Int(ceil(Double(modules.count) / 2.0))
        let leftModules = Array(modules.prefix(leftCount))
        let rightModules = Array(modules.dropFirst(leftCount))
        var spacing: CGFloat = 4
        let hitSize: CGFloat = 24
        let iconSize: CGFloat = 14

        let shapeWidth = registry.activeModule?.preferredSize.width ?? NotchPresets.open.w
        let flanks = geometry.topBandFlanks(inShapeSpace: shapeWidth)
        let forbidden = CGRect(
            x: geometry.forbiddenZone(inShapeSpace: shapeWidth).origin.x,
            y: 0,
            width: geometry.forbiddenZone(inShapeSpace: shapeWidth).width,
            height: geometry.notchRect.height
        )

        // Compute capacity and shrink spacing if needed
        func fits(modulesCount: Int, flankWidth: CGFloat) -> Bool {
            guard modulesCount > 0 else { return true }
            let total = CGFloat(modulesCount) * hitSize + CGFloat(max(0, modulesCount - 1)) * spacing + 16
            return flankWidth >= total
        }
        if !fits(modulesCount: leftModules.count, flankWidth: flanks.left.width) {
            spacing = max(2, spacing - 1)
        }
        if !fits(modulesCount: rightModules.count, flankWidth: flanks.right.width) {
            spacing = max(2, spacing - 1)
        }

        return ZStack {
            if hasNotch && shapeWidth > 0 {
                // Left flank group hugging forbidden zone
                HStack(spacing: spacing) {
                    ForEach(Array(leftModules.enumerated()), id: \.element.id) { _, module in
                        tabButton(module: module, hitSize: hitSize, iconSize: iconSize)
                    }
                }
                .padding(.leading, 8)
                .frame(height: notchHeight)
                .position(
                    x: flanks.left.maxX - (CGFloat(leftModules.count) * hitSize + CGFloat(max(0, leftModules.count - 1)) * spacing + 8) / 2 + (CGFloat(leftModules.count) * hitSize + CGFloat(max(0, leftModules.count - 1)) * spacing) / 2,
                    y: notchHeight / 2
                )
                .allowsHitTesting(true)

                // Right flank group
                HStack(spacing: spacing) {
                    ForEach(Array(rightModules.enumerated()), id: \.element.id) { _, module in
                        tabButton(module: module, hitSize: hitSize, iconSize: iconSize)
                    }
                }
                .padding(.trailing, 8)
                .frame(height: notchHeight)
                .position(
                    x: flanks.right.minX + (CGFloat(rightModules.count) * hitSize + CGFloat(max(0, rightModules.count - 1)) * spacing + 8) / 2 - (CGFloat(rightModules.count) * hitSize + CGFloat(max(0, rightModules.count - 1)) * spacing) / 2,
                    y: notchHeight / 2
                )
                .allowsHitTesting(true)
            } else {
                HStack(spacing: 6) {
                    ForEach(modules, id: \.id) { module in
                        tabButton(module: module, hitSize: hitSize, iconSize: iconSize)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: notchHeight)
                .position(x: shapeWidth / 2, y: notchHeight / 2)
                .allowsHitTesting(true)
            }
        }
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
