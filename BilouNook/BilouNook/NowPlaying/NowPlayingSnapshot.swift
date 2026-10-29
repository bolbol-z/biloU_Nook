import Foundation

struct NowPlayingSnapshot: Equatable {
    var title: String
    var artist: String
    var album: String
    var artwork: Data?
    var artworkMimeType: String?
    var isPlaying: Bool
    var elapsed: TimeInterval
    var duration: TimeInterval
    var bundleIdentifier: String?
    var updatedAt: Date

    init(
        title: String = "",
        artist: String = "",
        album: String = "",
        artwork: Data? = nil,
        artworkMimeType: String? = nil,
        isPlaying: Bool = false,
        elapsed: TimeInterval = 0,
        duration: TimeInterval = 0,
        bundleIdentifier: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.artworkMimeType = artworkMimeType
        self.isPlaying = isPlaying
        self.elapsed = elapsed
        self.duration = duration
        self.bundleIdentifier = bundleIdentifier
        self.updatedAt = updatedAt
    }

    var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trackIdentity: String {
        [bundleIdentifier ?? "", title, artist, album].joined(separator: "\u{1F}")
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }
}
