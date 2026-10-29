import Foundation

enum MediaTransportAction: Equatable {
    case restartTrack
    case previousTrack
}

enum MediaTransport {
    static let restartThreshold: TimeInterval = 3

    static func previousAction(elapsed: TimeInterval) -> MediaTransportAction {
        elapsed > restartThreshold ? .restartTrack : .previousTrack
    }
}
