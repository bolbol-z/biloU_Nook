import XCTest

final class MediaLayoutTests: XCTestCase {
    private let physicalShape = MediaShapeGeometry(
        width: 420,
        height: 150,
        topCornerRadius: 6,
        bottomCornerRadius: 14
    )
    private let noNotchShape = MediaShapeGeometry(
        width: 420,
        height: 150,
        topCornerRadius: 6,
        bottomCornerRadius: 14
    )

    func testStandardMetricsMatchApprovedDesign() {
        let metrics = MediaLayoutMetrics.standard

        XCTAssertEqual(metrics.sideClearance, 18, accuracy: 0.0001)
        XCTAssertEqual(metrics.topClearanceGap, 4, accuracy: 0.0001)
        XCTAssertEqual(metrics.bottomClearance, 14, accuracy: 0.0001)
        XCTAssertEqual(metrics.artworkSize, 76, accuracy: 0.0001)
        XCTAssertEqual(metrics.artworkCornerRadius, 12, accuracy: 0.0001)
        XCTAssertEqual(metrics.columnSpacing, 14, accuracy: 0.0001)
        XCTAssertEqual(metrics.sourceBadgeSize, 16, accuracy: 0.0001)
    }

    func testPhysicalNotchSafeAreaClearsHardwareAndShape() {
        let safeArea = NotchContentSafeArea.resolve(
            shape: physicalShape,
            notchHeight: 32,
            menuBarHeight: 24
        )

        XCTAssertEqual(safeArea.topClearance, 38, accuracy: 0.0001)
        XCTAssertEqual(safeArea.bottomInset, 14, accuracy: 0.0001)
        XCTAssertEqual(safeArea.leftInset, safeArea.rightInset, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(safeArea.leftInset, 18)
        XCTAssertGreaterThanOrEqual(safeArea.minimumDistance(from: safeArea.contentRect), 12)
    }

    func testNoNotchSafeAreaUsesMenuBarBand() {
        let safeArea = NotchContentSafeArea.resolve(
            shape: noNotchShape,
            notchHeight: 0,
            menuBarHeight: 24
        )

        XCTAssertEqual(safeArea.topClearance, 6, accuracy: 0.0001)
        XCTAssertEqual(safeArea.leftInset, safeArea.rightInset, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(safeArea.leftInset, 18)
    }

    func testPreferredHeightsPreserveTheApprovedRhythm() {
        XCTAssertEqual(
            MediaLayout.preferredHeight(notchHeight: 32, menuBarHeight: 24),
            32 + 6 + MediaLayout.contentHeight + MediaLayoutMetrics.standard.bottomClearance,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            MediaLayout.preferredSize(notchHeight: 32, menuBarHeight: 24).width,
            420,
            accuracy: 0.0001
        )
    }

    func testBottomArcAddsInsetBeyondTheStraightSide() {
        let safeArea = NotchContentSafeArea.resolve(
            shape: physicalShape,
            notchHeight: 32,
            menuBarHeight: 24
        )
        XCTAssertGreaterThanOrEqual(safeArea.leftInset, 18)
        XCTAssertEqual(safeArea.leftInset, safeArea.rightInset, accuracy: 0.0001)
    }

    func testNarrowShapeNeverProducesNegativeContent() {
        let safeArea = NotchContentSafeArea.resolve(
            shape: MediaShapeGeometry(
                width: 60,
                height: 60,
                topCornerRadius: 19,
                bottomCornerRadius: 24
            ),
            notchHeight: 32,
            menuBarHeight: 24
        )

        XCTAssertGreaterThanOrEqual(safeArea.contentRect.width, 0)
        XCTAssertGreaterThanOrEqual(safeArea.contentRect.height, 0)
    }
}
