import SwiftUI

struct ModuleB: NotchModule {
    let id = "module-b"
    let title = "Module B"
    let icon = "b.circle"
    let preferredSize = CGSize(width: 520, height: 160)

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
                title: "Module B",
                subtitle: "Placeholder content",
                symbol: "rectangle.3.group"
            )
        )
    }
}
