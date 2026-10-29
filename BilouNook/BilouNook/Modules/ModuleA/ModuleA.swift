import SwiftUI

struct ModuleA: NotchModule {
    let id = "module-a"
    let title = "Module A"
    let icon = "a.circle"
    let preferredSize = CGSize(width: 440, height: 140)

    var compactView: AnyView? {
        AnyView(
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        )
    }

    var expandedView: AnyView {
        AnyView(
            PlaceholderModuleView(
                title: "Module A",
                subtitle: "Placeholder content",
                symbol: "square.grid.2x2"
            )
        )
    }
}
