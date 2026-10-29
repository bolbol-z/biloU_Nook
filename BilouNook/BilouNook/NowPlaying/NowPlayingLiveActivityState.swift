import Foundation

struct NowPlayingLiveActivityState: Equatable {
    var isPlaying: Bool
    var trackIdentity: String
    var artwork: Data?

    init(isPlaying: Bool = false, trackIdentity: String = "", artwork: Data? = nil) {
        self.isPlaying = isPlaying
        self.trackIdentity = trackIdentity
        self.artwork = artwork
    }

    static let empty = NowPlayingLiveActivityState()

    var artworkIdentity: String {
        "\(trackIdentity)#\(artwork?.count ?? 0)"
    }

    static func from(_ snapshot: NowPlayingSnapshot?) -> NowPlayingLiveActivityState {
        guard let snapshot else { return .empty }
        return NowPlayingLiveActivityState(
            isPlaying: snapshot.isPlaying,
            trackIdentity: snapshot.trackIdentity,
            artwork: snapshot.artwork
        )
    }
}
