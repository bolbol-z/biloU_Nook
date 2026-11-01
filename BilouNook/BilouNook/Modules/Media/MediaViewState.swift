import Foundation

struct MediaPresentation: Equatable {
    let trackIdentity: String
    let title: String
    let artist: String
    let album: String
    let artwork: Data?
    let isPlaying: Bool
    let elapsed: TimeInterval
    let duration: TimeInterval
    let updatedAt: Date
    let bundleIdentifier: String
    let parentBundleIdentifier: String?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    var remaining: TimeInterval {
        guard duration > 0 else { return 0 }
        return max(0, duration - max(0, elapsed))
    }

    var isSeekable: Bool { duration > 0 }
    var playPauseSymbol: String { isPlaying ? "pause.fill" : "play.fill" }
    var artworkIdentity: String { "\(trackIdentity)#\(artwork?.count ?? 0)" }
}

enum MediaViewState: Equatable {
    case empty
    case track(MediaPresentation)

    init(snapshot: NowPlayingSnapshot?) {
        guard let snapshot, snapshot.hasContent else {
            self = .empty
            return
        }
        self = .track(
            MediaPresentation(
                trackIdentity: snapshot.trackIdentity,
                title: snapshot.title,
                artist: snapshot.artist,
                album: snapshot.album,
                artwork: snapshot.artwork,
                isPlaying: snapshot.isPlaying,
                elapsed: max(0, snapshot.elapsed),
                duration: max(0, snapshot.duration),
                updatedAt: snapshot.updatedAt,
                bundleIdentifier: snapshot.bundleIdentifier ?? "",
                parentBundleIdentifier: snapshot.parentApplicationBundleIdentifier
            )
        )
    }
}
