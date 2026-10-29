import XCTest

final class MediaViewStateTests: XCTestCase {
    private func snapshot(
        title: String = "Song",
        artist: String = "Artist",
        album: String = "Album",
        artwork: Data? = nil,
        isPlaying: Bool = true,
        elapsed: TimeInterval = 25,
        duration: TimeInterval = 100,
        bundleIdentifier: String = "com.example.player",
        updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: duration,
            bundleIdentifier: bundleIdentifier,
            updatedAt: updatedAt
        )
    }

    func testNilAndBlankSnapshotsMapToEmpty() {
        XCTAssertEqual(MediaViewState(snapshot: nil), .empty)
        XCTAssertEqual(
            MediaViewState(snapshot: NowPlayingSnapshot(title: "   ", artist: "", album: "")),
            .empty
        )
    }

    func testPausedTrackMapsToTrackWithPlaySymbol() throws {
        let state = MediaViewState(snapshot: snapshot(isPlaying: false))
        guard case .track(let presentation) = state else {
            return XCTFail("Expected track state")
        }

        XCTAssertEqual(presentation.title, "Song")
        XCTAssertEqual(presentation.artist, "Artist")
        XCTAssertEqual(presentation.album, "Album")
        XCTAssertEqual(presentation.playPauseSymbol, "play.fill")
        XCTAssertFalse(presentation.isPlaying)
        XCTAssertEqual(presentation.progress, 0.25, accuracy: 0.0001)
    }

    func testPlayingTrackMapsToPauseSymbol() throws {
        let state = MediaViewState(snapshot: snapshot(isPlaying: true))
        guard case .track(let presentation) = state else {
            return XCTFail("Expected track state")
        }

        XCTAssertEqual(presentation.playPauseSymbol, "pause.fill")
        XCTAssertTrue(presentation.isSeekable)
        XCTAssertEqual(presentation.remaining, 75, accuracy: 0.0001)
    }

    func testProgressAndRemainingClampToValidRange() throws {
        let state = MediaViewState(snapshot: snapshot(elapsed: 150, duration: 100))
        guard case .track(let presentation) = state else {
            return XCTFail("Expected track state")
        }

        XCTAssertEqual(presentation.progress, 1, accuracy: 0.0001)
        XCTAssertEqual(presentation.remaining, 0, accuracy: 0.0001)
    }

    func testNegativeElapsedClampsToZero() throws {
        let state = MediaViewState(snapshot: snapshot(elapsed: -10, duration: 100))
        guard case .track(let presentation) = state else {
            return XCTFail("Expected track state")
        }

        XCTAssertEqual(presentation.elapsed, 0)
        XCTAssertEqual(presentation.progress, 0)
    }

    func testUnknownDurationIsNotSeekable() throws {
        let state = MediaViewState(snapshot: snapshot(elapsed: 10, duration: 0))
        guard case .track(let presentation) = state else {
            return XCTFail("Expected track state")
        }

        XCTAssertFalse(presentation.isSeekable)
        XCTAssertEqual(presentation.progress, 0)
        XCTAssertEqual(presentation.remaining, 0)
    }

    func testPresentationCarriesSourceAndUpdateTimestamp() throws {
        let updatedAt = Date(timeIntervalSince1970: 4_200)
        let state = MediaViewState(
            snapshot: snapshot(
                bundleIdentifier: "com.spotify.client",
                updatedAt: updatedAt
            )
        )
        guard case .track(let presentation) = state else {
            return XCTFail("Expected track state")
        }

        XCTAssertEqual(presentation.bundleIdentifier, "com.spotify.client")
        XCTAssertEqual(presentation.updatedAt, updatedAt)
    }

    func testArtworkIdentityChangesWithArtwork() throws {
        let withArtwork = MediaViewState(snapshot: snapshot(artwork: Data([1, 2, 3])))
        let withoutArtwork = MediaViewState(snapshot: snapshot(artwork: nil))
        guard
            case .track(let first) = withArtwork,
            case .track(let second) = withoutArtwork
        else {
            return XCTFail("Expected track states")
        }

        XCTAssertNotEqual(first.artworkIdentity, second.artworkIdentity)
    }
}
