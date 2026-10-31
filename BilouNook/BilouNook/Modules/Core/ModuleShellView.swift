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

    private var tabContent: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var geometry: NotchGeometry {
        let screen = ScreenResolver.shared.targetScreen()
        return NotchGeometry.live(for: screen)
    }

    private var notchHeight: CGFloat {
        geometry.notchRect.height
    }

    private var hasNotch: Bool {
        geometry.isPhysicalNotch
    }

    private struct FlankLayout {
        let allModules: [any NotchModule]
        let leftModules: [any NotchModule]
        let rightModules: [any NotchModule]
        let spacing: CGFloat
        let hitSize: CGFloat
        let iconSize: CGFloat
        let shapeWidth: CGFloat
        let notchHeight: CGFloat
        let hasNotch: Bool
        let leftPositionX: CGFloat
        let rightPositionX: CGFloat
        let centerPositionX: CGFloat
    }

    private var flankTabBar: some View {
        let layout = flankLayout
        return ZStack {
            if layout.hasNotch && layout.shapeWidth > 0 {
                tabGroup(
                    modules: layout.leftModules,
                    spacing: layout.spacing,
                    hitSize: layout.hitSize,
                    iconSize: layout.iconSize,
                    height: layout.notchHeight,
                    edge: .leading,
                    padding: 8
                )
                .position(x: layout.leftPositionX, y: layout.notchHeight / 2)

                tabGroup(
                    modules: layout.rightModules,
                    spacing: layout.spacing,
                    hitSize: layout.hitSize,
                    iconSize: layout.iconSize,
                    height: layout.notchHeight,
                    edge: .trailing,
                    padding: 8
                )
                .position(x: layout.rightPositionX, y: layout.notchHeight / 2)
            } else {
                tabGroup(
                    modules: layout.allModules,
                    spacing: 6,
                    hitSize: layout.hitSize,
                    iconSize: layout.iconSize,
                    height: layout.notchHeight,
                    edge: .horizontal,
                    padding: 12
                )
                .position(x: layout.centerPositionX, y: layout.notchHeight / 2)
            }
        }
        .allowsHitTesting(true)
    }

    private var flankLayout: FlankLayout {
        let modules = registry.enabledModules
        let leftCount = Int(ceil(Double(modules.count) / 2.0))
        let leftModules = Array(modules.prefix(leftCount))
        let rightModules = Array(modules.dropFirst(leftCount))
        let hitSize: CGFloat = 24
        let iconSize: CGFloat = 14
        let shapeWidth: CGFloat = registry.activeModule?.preferredSize.width ?? NotchPresets.open.w
        let flanks = geometry.topBandFlanks(inShapeSpace: shapeWidth)
        var spacing: CGFloat = 4

        if !Self.fits(count: leftModules.count, flankWidth: flanks.left.width, hitSize: hitSize, spacing: spacing) {
            spacing = max(2, spacing - 1)
        }
        if !Self.fits(count: rightModules.count, flankWidth: flanks.right.width, hitSize: hitSize, spacing: spacing) {
            spacing = max(2, spacing - 1)
        }

        let leftGroupWidth: CGFloat = Self.groupWidth(count: leftModules.count, hitSize: hitSize, spacing: spacing)
        let rightGroupWidth: CGFloat = Self.groupWidth(count: rightModules.count, hitSize: hitSize, spacing: spacing)
        let leftPositionX: CGFloat = flanks.left.maxX - (leftGroupWidth + 8) / 2 + leftGroupWidth / 2
        let rightPositionX: CGFloat = flanks.right.minX + (rightGroupWidth + 8) / 2 - rightGroupWidth / 2
        let centerPositionX: CGFloat = shapeWidth / 2

        return FlankLayout(
            allModules: modules,
            leftModules: leftModules,
            rightModules: rightModules,
            spacing: spacing,
            hitSize: hitSize,
            iconSize: iconSize,
            shapeWidth: shapeWidth,
            notchHeight: notchHeight,
            hasNotch: hasNotch,
            leftPositionX: leftPositionX,
            rightPositionX: rightPositionX,
            centerPositionX: centerPositionX
        )
    }

    private static func fits(count: Int, flankWidth: CGFloat, hitSize: CGFloat, spacing: CGFloat) -> Bool {
        guard count > 0 else { return true }
        let total: CGFloat = CGFloat(count) * hitSize + CGFloat(max(0, count - 1)) * spacing + 16
        return flankWidth >= total
    }

    private static func groupWidth(count: Int, hitSize: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(count) * hitSize + CGFloat(max(0, count - 1)) * spacing
    }

    private func tabGroup(
        modules: [any NotchModule],
        spacing: CGFloat,
        hitSize: CGFloat,
        iconSize: CGFloat,
        height: CGFloat,
        edge: Edge.Set,
        padding: CGFloat
    ) -> some View {
        HStack(spacing: spacing) {
            ForEach(modules, id: \.id) { module in
                tabButton(module: module, hitSize: hitSize, iconSize: iconSize)
            }
        }
        .padding(edge, padding)
        .frame(height: height)
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
