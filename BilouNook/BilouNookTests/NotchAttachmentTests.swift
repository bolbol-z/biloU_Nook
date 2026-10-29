import AppKit
import XCTest

final class NotchAttachmentTests: XCTestCase {
    func testHardwareNotchRectUsesAuxiliaryAreaWidths() {
        let rect = NotchAttachment.hardwareNotchRect(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            auxLeft: CGRect(x: 0, y: 0, width: 656, height: 32),
            auxRight: CGRect(x: 856, y: 0, width: 656, height: 32),
            safeAreaTop: 32
        )

        XCTAssertEqual(rect.minX, 656, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 200, accuracy: 0.0001)
        XCTAssertEqual(rect.minY, 950, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 32, accuracy: 0.0001)
    }

    func testHardwareNotchRectIsEmptyWithoutNotch() {
        let rect = NotchAttachment.hardwareNotchRect(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )

        XCTAssertEqual(rect, .zero)
    }

    func testHardwareNotchRectNeverHasNegativeWidth() {
        let rect = NotchAttachment.hardwareNotchRect(
            screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            auxLeft: CGRect(x: 0, y: 0, width: 600, height: 30),
            auxRight: CGRect(x: 500, y: 0, width: 500, height: 30),
            safeAreaTop: 30
        )

        XCTAssertEqual(rect, .zero)
    }

    func testBackingAlignedRectSnapsEveryEdge() {
        let rect = NotchAttachment.backingAlignedRect(
            CGRect(x: 100.25, y: 10.25, width: 50.25, height: 20.25),
            scale: 2
        )

        XCTAssertEqual(rect.minX, 100.5, accuracy: 0.0001)
        XCTAssertEqual(rect.minY, 10.5, accuracy: 0.0001)
        XCTAssertEqual(rect.maxX, 150.5, accuracy: 0.0001)
        XCTAssertEqual(rect.maxY, 30.5, accuracy: 0.0001)
    }

    func testPanelFrameAttachesToScreenTopAndCentersHorizontally() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = NotchAttachment.panelFrame(
            screenFrame: screen,
            panelSize: CGSize(width: 680, height: 247.5),
            scale: 2
        )

        XCTAssertEqual(rect.midX, screen.midX, accuracy: 0.0001)
        XCTAssertEqual(rect.maxY, screen.maxY, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 680, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 247.5, accuracy: 0.0001)
    }
}
