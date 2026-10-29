import AppKit
import XCTest

final class LiveActivityLayoutTests: XCTestCase {
    private let base = NotchMetrics(w: 179, h: 32, t: 6, b: 14)

    func testPhysicalNotchWidthUsesAuxiliaryGap() throws {
        let left = NSRect(x: 0, y: 924, width: 646, height: 32)
        let right = NSRect(x: 825, y: 924, width: 645, height: 32)

        let width = try XCTUnwrap(
            LiveActivityLayout.physicalNotchWidth(
                auxLeft: left,
                auxRight: right,
                safeAreaTop: 32,
                closedWidth: 179
            )
        )

        XCTAssertEqual(width, 179, accuracy: 0.0001)
    }

    func testPhysicalNotchWidthFallsBackToClosedWidthWithSafeArea() throws {
        let width = try XCTUnwrap(
            LiveActivityLayout.physicalNotchWidth(
                auxLeft: nil,
                auxRight: nil,
                safeAreaTop: 24,
                closedWidth: 200
            )
        )

        XCTAssertEqual(width, 200, accuracy: 0.0001)
    }

    func testPhysicalNotchWidthIsNilWithoutNotch() {
        let width = LiveActivityLayout.physicalNotchWidth(
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0,
            closedWidth: 184
        )

        XCTAssertNil(width)
    }

    func testExactNotchFootprintWidensWhileActive() {
        let metrics = LiveActivityLayout.closedMetrics(
            base: base,
            physicalNotchWidth: 179,
            isLiveActivityActive: true
        )

        XCTAssertEqual(metrics.w, 251, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, base.h)
    }

    func testAlreadyWideFootprintIsUnchanged() {
        let wide = NotchMetrics(w: 280, h: 32, t: 6, b: 14)
        let metrics = LiveActivityLayout.closedMetrics(
            base: wide,
            physicalNotchWidth: 179,
            isLiveActivityActive: true
        )

        XCTAssertEqual(metrics.w, 280)
    }

    func testNoNotchVirtualNotchStillGetsWings() {
        let wideEnough = LiveActivityLayout.closedMetrics(
            base: NotchMetrics(w: 184, h: 8, t: 6, b: 14),
            physicalNotchWidth: nil,
            isLiveActivityActive: true
        )
        XCTAssertEqual(wideEnough.w, 256)

        let tooNarrow = LiveActivityLayout.closedMetrics(
            base: NotchMetrics(w: 50, h: 8, t: 6, b: 14),
            physicalNotchWidth: nil,
            isLiveActivityActive: true
        )
        XCTAssertEqual(tooNarrow.w, 122)
    }

    func testInactiveLiveActivityKeepsBaseMetrics() {
        let metrics = LiveActivityLayout.closedMetrics(
            base: base,
            physicalNotchWidth: 179,
            isLiveActivityActive: false
        )

        XCTAssertEqual(metrics.w, 179)
        XCTAssertEqual(metrics.h, 32)
    }
}
