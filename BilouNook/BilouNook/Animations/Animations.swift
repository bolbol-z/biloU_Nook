import SwiftUI

enum Animations {
    // Dynamic Island style - tuned
    static var hoverOpen = Animation.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0)
    static var hoverClose = Animation.spring(response: 0.28, dampingFraction: 1.0, blendDuration: 0)
    static var hoverClosePure = Animation.spring(response: 0.28, dampingFraction: 1.0, blendDuration: 0)
    
    static var openFootprint = Animation.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0)
    static var closeFootprint = Animation.spring(response: 0.28, dampingFraction: 1.0, blendDuration: 0)
    
    static var contentIn = Animation.spring(response: 0.24, dampingFraction: 0.9, blendDuration: 0).delay(0.05)
    static var contentOut = Animation.spring(response: 0.18, dampingFraction: 0.95, blendDuration: 0)
    
    static var scrubFollow = Animation.interactiveSpring(response: 0.15, dampingFraction: 1.0, blendDuration: 0.25)
    static var scrubDrag = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.58, blendDuration: 0.25)
    
    static var timeScale: Double = 1.0
    
    static func scaled(_ animation: Animation) -> Animation {
        var scale = timeScale
        if SettingsStore.shared.slowMotion {
            scale = max(scale, 4.0)
        }
        if scale == 1.0 { return animation }
        return animation.speed(1.0 / scale)
    }
}

struct ScaleBlurOpacityContentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scaleEffect(0.8, anchor: UnitPoint(x: 0.5, y: -0.25))
            .blur(radius: 10)
            .opacity(0)
            .onAppear {
                withAnimation(Animations.scaled(Animations.contentIn)) {
                }
            }
    }
}

struct NotchContentTransitionModifier: ViewModifier {
    var active: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.0 : 0.8, anchor: UnitPoint(x: 0.5, y: -0.25))
            .blur(radius: active ? 0 : 10)
            .opacity(active ? 1.0 : 0)
            .animation(Animations.scaled(active ? Animations.contentIn : Animations.contentOut), value: active)
    }
}
