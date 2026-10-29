import AppKit
import XCTest

final class NotchGeometryTests: XCTestCase {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)

    private var physicalGeometry: NotchGeometry {
        NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: CGRect(x: 0, y: 924, width: 646, height: 32),
            auxRight: CGRect(x: 825, y: 924, width: 645, height: 32),
            safeAreaTop: 32
        )
    }

    func testPhysicalNotchRectComesFromAuxiliaryGapAndSafeArea() throws {
        let geometry = physicalGeometry
        let rect = try XCTUnwrap(geometry.hardwareNotchRect)

        XCTAssertEqual(rect.minX, 646, accuracy: 0.0001)
        XCTAssertEqual(rect.minY, 924, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 179, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 32, accuracy: 0.0001)
        XCTAssertTrue(geometry.isPhysicalNotch)
    }

    func testClosedNotchCoversHardwareWithHalfPointOverlapAndSharedRadii() {
        let metrics = physicalGeometry.closedMetrics(isLiveActivityActive: false)

        XCTAssertEqual(metrics.w, 180, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, 32.5, accuracy: 0.0001)
        XCTAssertEqual(metrics.t, 6, accuracy: 0.0001)
        XCTAssertEqual(metrics.b, 14, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(metrics.w, 179)
        XCTAssertGreaterThan(metrics.t, 0)
    }

    func testVirtualNotchIsCenteredAndPixelAlignedWhenHardwareIsMissing() {
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )

        XCTAssertNil(geometry.hardwareNotchRect)
        XCTAssertFalse(geometry.isPhysicalNotch)
        XCTAssertEqual(geometry.virtualNotchRect.minX, 635, accuracy: 0.0001)
        XCTAssertEqual(geometry.virtualNotchRect.minY, 924, accuracy: 0.0001)
        XCTAssertEqual(geometry.virtualNotchRect.width, 200, accuracy: 0.0001)
        XCTAssertEqual(geometry.virtualNotchRect.height, 32, accuracy: 0.0001)

        let metrics = geometry.closedMetrics(isLiveActivityActive: false)
        XCTAssertEqual(metrics.w, 201, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, 32.5, accuracy: 0.0001)
        XCTAssertEqual(metrics.t, 6, accuracy: 0.0001)
        XCTAssertEqual(metrics.b, 14, accuracy: 0.0001)
    }

    func testLiveActivityWingsGrowFromVirtualNotchToo() {
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )

        let metrics = geometry.closedMetrics(isLiveActivityActive: true)
        XCTAssertEqual(metrics.w, 272, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, 32.5, accuracy: 0.0001)
    }

    func testLiveActivityWingsGrowFromPhysicalNotchWithoutChangingRadii() {
        let metrics = physicalGeometry.closedMetrics(isLiveActivityActive: true)

        XCTAssertEqual(metrics.w, 251, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, 32.5, accuracy: 0.0001)
        XCTAssertEqual(metrics.t, 6, accuracy: 0.0001)
        XCTAssertEqual(metrics.b, 14, accuracy: 0.0001)
    }

    func testOpenShapeKeepsTheClosedRadiusPair() {
        let closed = physicalGeometry.closedMetrics(isLiveActivityActive: false)
        let open = physicalGeometry.openMetrics(for: CGSize(width: 520, height: 225))

        XCTAssertEqual(open.w, 520, accuracy: 0.0001)
        XCTAssertEqual(open.h, 225, accuracy: 0.0001)
        XCTAssertEqual(open.t, closed.t, accuracy: 0.0001)
        XCTAssertEqual(open.b, closed.b, accuracy: 0.0001)
    }

    func testScaledDisplaySnapsWidthToEvenPixelsAndHeightUpToPixel() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: CGRect(x: 0, y: 1050, width: 700, height: 30),
            auxRight: CGRect(x: 1220, y: 1050, width: 700, height: 30),
            safeAreaTop: 30
        )

        let metrics = geometry.closedMetrics(isLiveActivityActive: false)
        XCTAssertEqual(geometry.hardwareNotchRect?.width ?? 0, 520, accuracy: 0.0001)
        XCTAssertEqual(metrics.w, 522, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, 31, accuracy: 0.0001)
        XCTAssertEqual(metrics.t, 5.625, accuracy: 0.0001)
        XCTAssertEqual(metrics.b, 13.125, accuracy: 0.0001)
    }

    func testExternalDisplayWithoutNotchUsesVirtualNotchMetrics() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )

        let metrics = geometry.closedMetrics(isLiveActivityActive: false)
        XCTAssertNil(geometry.hardwareNotchRect)
        XCTAssertEqual(geometry.virtualNotchRect.midX, 2472, accuracy: 0.0001)
        XCTAssertEqual(metrics.w, 202, accuracy: 0.0001)
        XCTAssertEqual(metrics.h, 33, accuracy: 0.0001)
    }

    func testRadiusInterpolationIsLinearAndMatchesBothEndpoints() {
        let closed = physicalGeometry.closedMetrics(isLiveActivityActive: false)
        let open = NotchMetrics(w: 520, h: 225, t: 12, b: 20)
        let samples = [0, 0.25, 0.5, 0.75, 1].map {
            NotchMorph.metrics(from: closed, to: open, progress: CGFloat($0))
        }

        XCTAssertEqual(samples[0].t, closed.t, accuracy: 0.0001)
        XCTAssertEqual(samples[0].b, closed.b, accuracy: 0.0001)
        XCTAssertEqual(samples[4].t, open.t, accuracy: 0.0001)
        XCTAssertEqual(samples[4].b, open.b, accuracy: 0.0001)

        let topSteps = zip(samples, samples.dropFirst()).map { $1.t - $0.t }
        let bottomSteps = zip(samples, samples.dropFirst()).map { $1.b - $0.b }
        for step in topSteps {
            XCTAssertEqual(step, (open.t - closed.t) / 4, accuracy: 0.0001)
        }
        for step in bottomSteps {
            XCTAssertEqual(step, (open.b - closed.b) / 4, accuracy: 0.0001)
        }
    }

    func testShapeClampKeepsRadiiAtHalfTheSmallestDimension() {
        let clamped = NotchShapeMetrics.clamped(
            NotchMetrics(w: 8, h: 10, t: 40, b: -3)
        )

        XCTAssertEqual(clamped.t, 4, accuracy: 0.0001)
        XCTAssertEqual(clamped.b, 0, accuracy: 0.0001)
    }
}
