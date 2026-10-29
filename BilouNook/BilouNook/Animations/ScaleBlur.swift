import SwiftUI

struct ScaleBlur: ViewModifier {
    var on: Bool
    let scale: CGFloat
    let blurRadius: CGFloat
    let anchor: UnitPoint
    
    init(on: Bool) {
        self.on = on
        self.scale = CGFloat(SettingsStore.shared.contentScale_ASSUMPTION)
        self.blurRadius = CGFloat(SettingsStore.shared.contentBlur_ASSUMPTION)
        self.anchor = UnitPoint(x: 0.5, y: CGFloat(SettingsStore.shared.contentAnchorY_ASSUMPTION))
    }
    
    init(on: Bool, scale: CGFloat, blurRadius: CGFloat, anchorY: CGFloat) {
        self.on = on
        self.scale = scale
        self.blurRadius = blurRadius
        self.anchor = UnitPoint(x: 0.5, y: anchorY)
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? scale : 1.0, anchor: anchor)
            .blur(radius: on ? blurRadius : 0)
            .opacity(on ? 0 : 1.0)
    }
}

extension AnyTransition {
    static func scaleBlur() -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: ScaleBlur(on: true), identity: ScaleBlur(on: false)).animation(Animations.contentIn),
            removal: .modifier(active: ScaleBlur(on: true), identity: ScaleBlur(on: false)).animation(Animations.contentOut)
        )
    }
}
