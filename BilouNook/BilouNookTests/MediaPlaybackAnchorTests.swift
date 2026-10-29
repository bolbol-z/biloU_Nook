import XCTest

final class MediaPlaybackAnchorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    private func presentation(
        elapsed: TimeInterval,
        updatedAt: Date,
        isPlaying: Bool = true,
        duration: TimeInterval = 100
    ) -> MediaPresentation {
        MediaPresentation(
            trackIdentity: "track",
            title: "Song",
            artist: "Artist",
            album: "Album",
            artwork: nil,
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: duration,
            updatedAt: updatedAt,
            bundleIdentifier: "com.example.player"
        )
    }

    func testPlayingAnchorExtrapolatesAndClamps() {
        let anchor = MediaPlaybackAnchor(
            elapsedAtAnchor: 10,
            anchorDate: start,
            isPlaying: true
        )

        XCTAssertEqual(anchor.elapsed(at: start.addingTimeInterval(5), duration: 100), 15, accuracy: 0.0001)
        XCTAssertEqual(anchor.elapsed(at: start.addingTimeInterval(500), duration: 100), 100, accuracy: 0.0001)
        XCTAssertEqual(anchor.progress(duration: 100, at: start.addingTimeInterval(5)), 0.15, accuracy: 0.0001)
    }

    func testPausedAnchorDoesNotAdvance() {
        let anchor = MediaPlaybackAnchor(
            elapsedAtAnchor: 42,
            anchorDate: start,
            isPlaying: false
        )

        XCTAssertEqual(anchor.elapsed(at: start.addingTimeInterval(20), duration: 100), 42, accuracy: 0.0001)
    }

    func testAnchorNeverProjectsBeforeItsDate() {
        let anchor = MediaPlaybackAnchor(
            elapsedAtAnchor: 18,
            anchorDate: start,
            isPlaying: true
        )

        XCTAssertEqual(anchor.elapsed(at: start.addingTimeInterval(-5), duration: 100), 18, accuracy: 0.0001)
    }

    func testPresentationAnchorRemovesLocallyAdvancedElapsed() {
        let anchor = MediaPlaybackAnchor(
            presentation: presentation(
                elapsed: 12,
                updatedAt: start
            ),
            now: start.addingTimeInterval(2)
        )

        XCTAssertEqual(anchor.elapsedAtAnchor, 10, accuracy: 0.0001)
        XCTAssertEqual(anchor.anchorDate, start)
        XCTAssertEqual(anchor.elapsed(at: start.addingTimeInterval(5), duration: 100), 15, accuracy: 0.0001)
    }

    func testSeekAnchorStartsAtTargetImmediately() {
        let anchor = MediaPlaybackAnchor(
            elapsedAtAnchor: 10,
            anchorDate: start,
            isPlaying: true
        )

        let moved = anchor.withElapsed(70, at: start.addingTimeInterval(1))

        XCTAssertEqual(moved.elapsedAtAnchor, 70)
        XCTAssertEqual(moved.anchorDate, start.addingTimeInterval(1))
        XCTAssertTrue(moved.isPlaying)
    }

    func testNegativeDurationIsNotProjectable() {
        let anchor = MediaPlaybackAnchor(
            elapsedAtAnchor: 10,
            anchorDate: start,
            isPlaying: true
        )

        XCTAssertEqual(anchor.elapsed(at: start.addingTimeInterval(5), duration: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(anchor.progress(duration: 0, at: start), 0, accuracy: 0.0001)
    }
}
