import XCTest

final class MediaTransportTests: XCTestCase {
    func testPreviousRestartsAfterThreeSeconds() {
        XCTAssertEqual(MediaTransport.previousAction(elapsed: 3.01), .restartTrack)
        XCTAssertEqual(MediaTransport.previousAction(elapsed: 20), .restartTrack)
    }

    func testPreviousGoesBackAtOrBeforeThreeSeconds() {
        XCTAssertEqual(MediaTransport.previousAction(elapsed: 3), .previousTrack)
        XCTAssertEqual(MediaTransport.previousAction(elapsed: 0.2), .previousTrack)
    }
}
