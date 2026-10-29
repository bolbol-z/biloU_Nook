import SwiftUI

enum MediaMotion {
    static let trackSpring = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let artworkSpring = Animation.spring(response: 0.32, dampingFraction: 0.8)
    static let controlSpring = Animation.spring(response: 0.24, dampingFraction: 0.72)
    static let trackChange = Animation.spring(response: 0.36, dampingFraction: 0.86)
    static let seekSettle = Animation.spring(response: 0.32, dampingFraction: 0.9)
    static let tintFade = Animation.easeOut(duration: 0.45)

    static func respectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.01) : animation
    }
}
