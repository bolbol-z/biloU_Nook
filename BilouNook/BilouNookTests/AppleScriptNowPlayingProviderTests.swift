import XCTest

final class AppleScriptNowPlayingProviderTests: XCTestCase {
    private func snapshot(_ fields: [String], divisor: Double = 1) -> NowPlayingSnapshot? {
        AppleScriptNowPlayingProvider.snapshot(
            fields: fields,
            durationDivisor: divisor,
            bundleIdentifier: "com.example.player"
        )
    }

    func testPreservesPipesNewlinesAndUnicodeInFields() {
        let title = "A | B\nC — café 東京"
        let artist = "Artist | Featured"
        let album = "Album\nDeluxe"

        let result = snapshot(["playing", "12.5", title, artist, album, "100"])

        XCTAssertEqual(result?.title, title)
        XCTAssertEqual(result?.artist, artist)
        XCTAssertEqual(result?.album, album)
        XCTAssertEqual(result?.elapsed, 12.5)
        XCTAssertEqual(result?.duration, 100)
        XCTAssertEqual(result?.isPlaying, true)
    }

    func testRequiresExactlySixFields() {
        XCTAssertNil(snapshot(["playing", "10", "Title", "Artist", "Album"]))
        XCTAssertNil(snapshot(["playing", "10", "Title", "Artist", "Album", "100", "extra"]))
    }

    func testAllowsEmptyOptionalFields() {
        let result = snapshot(["paused", "0", "Title", "", "", "0"])

        XCTAssertEqual(result?.title, "Title")
        XCTAssertEqual(result?.artist, "")
        XCTAssertEqual(result?.album, "")
        XCTAssertEqual(result?.duration, 0)
        XCTAssertEqual(result?.isPlaying, false)
    }

    func testRejectsEmptyTitleAndUnknownState() {
        XCTAssertNil(snapshot(["playing", "10", "   ", "Artist", "Album", "100"]))
        XCTAssertNil(snapshot(["stopped", "10", "Title", "Artist", "Album", "100"]))
    }

    func testSpotifyDurationUsesMilliseconds() {
        let result = snapshot(["playing", "12.5", "Title", "Artist", "Album", "205000"], divisor: 1_000)

        XCTAssertEqual(result?.duration, 205)
        XCTAssertEqual(result?.elapsed, 12.5)
    }

    func testElapsedClampsToDuration() {
        let result = snapshot(["playing", "120", "Title", "Artist", "Album", "100"])

        XCTAssertEqual(result?.elapsed, 100)
    }
}
