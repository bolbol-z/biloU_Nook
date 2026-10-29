import Foundation

struct MediaPlaybackAnchor: Equatable {
    var elapsedAtAnchor: TimeInterval
    var anchorDate: Date
    var isPlaying: Bool

    init(elapsedAtAnchor: TimeInterval, anchorDate: Date, isPlaying: Bool) {
        self.elapsedAtAnchor = max(0, elapsedAtAnchor)
        self.anchorDate = anchorDate
        self.isPlaying = isPlaying
    }

    init(presentation: MediaPresentation, now: Date) {
        let age = max(0, now.timeIntervalSince(presentation.updatedAt))
        let elapsed = presentation.isPlaying ? presentation.elapsed - age : presentation.elapsed
        self.init(
            elapsedAtAnchor: elapsed,
            anchorDate: presentation.updatedAt,
            isPlaying: presentation.isPlaying
        )
    }

    func elapsed(at date: Date, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        let age = isPlaying ? max(0, date.timeIntervalSince(anchorDate)) : 0
        return min(max(0, elapsedAtAnchor + age), duration)
    }

    func progress(duration: TimeInterval, at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return elapsed(at: date, duration: duration) / duration
    }

    func withElapsed(_ elapsed: TimeInterval, at date: Date) -> MediaPlaybackAnchor {
        MediaPlaybackAnchor(
            elapsedAtAnchor: elapsed,
            anchorDate: date,
            isPlaying: isPlaying
        )
    }
}
