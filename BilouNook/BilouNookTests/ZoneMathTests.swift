import AppKit
import XCTest

final class ZoneMathTests: XCTestCase {
    private let rect = NSRect(x: 100, y: 200, width: 50, height: 30)

    func testEdgesAreInclusive() {
        XCTAssertTrue(ZoneMath.contains(rect, NSPoint(x: rect.minX, y: rect.midY)))
        XCTAssertTrue(ZoneMath.contains(rect, NSPoint(x: rect.maxX, y: rect.midY)))
        XCTAssertTrue(ZoneMath.contains(rect, NSPoint(x: rect.midX, y: rect.minY)))
        XCTAssertTrue(ZoneMath.contains(rect, NSPoint(x: rect.midX, y: rect.maxY)))
        XCTAssertTrue(ZoneMath.contains(rect, NSPoint(x: rect.midX, y: rect.midY)))
    }

    func testJustOutsideIsExcluded() {
        XCTAssertFalse(ZoneMath.contains(rect, NSPoint(x: rect.minX - 0.01, y: rect.midY)))
        XCTAssertFalse(ZoneMath.contains(rect, NSPoint(x: rect.maxX + 0.01, y: rect.midY)))
        XCTAssertFalse(ZoneMath.contains(rect, NSPoint(x: rect.midX, y: rect.minY - 0.01)))
        XCTAssertFalse(ZoneMath.contains(rect, NSPoint(x: rect.midX, y: rect.maxY + 0.01)))
    }

    func testTopExtensionIsSixPoints() {
        XCTAssertEqual(ZoneMath.topExtension, 6, accuracy: 0.0001)
    }
}
