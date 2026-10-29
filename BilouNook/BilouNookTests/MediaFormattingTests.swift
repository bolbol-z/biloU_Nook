import XCTest

final class MediaFormattingTests: XCTestCase {
    func testFormatsSecondsAndMinutes() {
        XCTAssertEqual(MediaFormatting.time(0), "0:00")
        XCTAssertEqual(MediaFormatting.time(5), "0:05")
        XCTAssertEqual(MediaFormatting.time(59), "0:59")
        XCTAssertEqual(MediaFormatting.time(60), "1:00")
        XCTAssertEqual(MediaFormatting.time(3599), "59:59")
    }

    func testFormatsHours() {
        XCTAssertEqual(MediaFormatting.time(3600), "1:00:00")
        XCTAssertEqual(MediaFormatting.time(3725), "1:02:05")
    }

    func testClampsInvalidAndNegativeTimes() {
        XCTAssertEqual(MediaFormatting.time(-5), "0:00")
        XCTAssertEqual(MediaFormatting.time(.nan), "0:00")
        XCTAssertEqual(MediaFormatting.time(.infinity), "0:00")
    }

    func testRemainingUsesMinusPrefix() {
        XCTAssertEqual(MediaFormatting.remaining(elapsed: 10, duration: 100), "-1:30")
        XCTAssertEqual(MediaFormatting.remaining(elapsed: 100, duration: 100), "-0:00")
        XCTAssertEqual(MediaFormatting.remaining(elapsed: 120, duration: 100), "-0:00")
    }

    func testRemainingIsUnknownWithoutDuration() {
        XCTAssertEqual(MediaFormatting.remaining(elapsed: 10, duration: 0), "--:--")
        XCTAssertEqual(MediaFormatting.remaining(elapsed: 10, duration: .nan), "--:--")
    }

    func testRemainingHandlesInvalidElapsed() {
        XCTAssertEqual(MediaFormatting.remaining(elapsed: .nan, duration: 100), "-1:40")
    }
}
