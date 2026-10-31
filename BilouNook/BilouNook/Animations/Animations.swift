import SwiftUI

enum NotchMotionTransition: Equatable {
    case openMetrics
    case closeMetrics
    case contentShow
    case contentHide
    case liveActivity
    case moduleChange
}

enum NotchMotionPlan: Equatable {
    case spring(response: Double, dampingFraction: Double)
    case easeIn(duration: Double)
    case easeInOut(duration: Double)
    case crossfade(duration: Double)
}

enum Animations {
    static let contentShowDelay: TimeInterval = 0.05
    static let clickThroughDelay: TimeInterval = 0.2
    static let reduceMotionDuration: TimeInterval = 0.15

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

    static func plan(for transition: NotchMotionTransition, reduceMotion: Bool) -> NotchMotionPlan {
        if reduceMotion {
            return .crossfade(duration: reduceMotionDuration)
        }
        switch transition {
        case .openMetrics, .moduleChange:
            return .spring(response: 0.28, dampingFraction: 0.9)
        case .closeMetrics:
            return .spring(response: 0.28, dampingFraction: 1.0)
        case .contentShow:
            return .spring(response: 0.32, dampingFraction: 0.9)
        case .contentHide:
            return .easeIn(duration: 0.12)
        case .liveActivity:
            return .easeInOut(duration: 0.12)
        }
    }

    static func animation(for plan: NotchMotionPlan) -> Animation {
        switch plan {
        case .spring(let response, let dampingFraction):
            return scaled(.spring(response: response, dampingFraction: dampingFraction))
        case .easeIn(let duration):
            return scaled(.easeIn(duration: duration))
        case .easeInOut(let duration):
            return scaled(.easeInOut(duration: duration))
        case .crossfade(let duration):
            return .easeInOut(duration: duration)
        }
    }

    static func scaled(_ animation: Animation) -> Animation {
        var scale = timeScale
        if SettingsStore.shared.slowMotion {
            scale = max(scale, 4.0)
        }
        if scale == 1.0 { return animation }
        return animation.speed(1.0 / scale)
    }
}
