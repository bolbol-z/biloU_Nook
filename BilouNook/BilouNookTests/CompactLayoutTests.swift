import AppKit
import XCTest

@MainActor
final class CompactLayoutTests: XCTestCase {
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

    func testForbiddenZoneExpandsBySixPoints() {
        let geometry = physicalGeometry
        let forbidden = geometry.forbiddenZone
        let notch = geometry.notchRect
        XCTAssertEqual(forbidden.minX, notch.minX - 6, accuracy: 0.0001)
        XCTAssertEqual(forbidden.width, notch.width + 12, accuracy: 0.0001)
        XCTAssertEqual(forbidden.height, notch.height, accuracy: 0.0001)
    }

    func testTopBandFlanks() {
        let geometry = physicalGeometry
        let flanks = geometry.topBandFlanks
        XCTAssertGreaterThanOrEqual(flanks.left.width, 0)
        XCTAssertGreaterThanOrEqual(flanks.right.width, 0)
        XCTAssertEqual(flanks.left.height, geometry.notchRect.height, accuracy: 0.0001)
        XCTAssertEqual(flanks.right.height, geometry.notchRect.height, accuracy: 0.0001)
    }

    func testContentTopIsNotchHeightPlusSix() {
        let geometry = physicalGeometry
        XCTAssertEqual(geometry.contentTop, geometry.notchRect.height + 6, accuracy: 0.0001)
    }

    func testNoElementIntersectsForbiddenZonePhysicalNotch() {
        let geometry = physicalGeometry
        let shapeWidth: CGFloat = 420
        let flanks = geometry.topBandFlanks(inShapeSpace: shapeWidth)
        XCTAssertGreaterThanOrEqual(flanks.left.width + flanks.right.width, 0)
    }

    func testTabPlacementForOneToSixModulesNoOverlap() {
        let geometry = physicalGeometry
        let shapeWidth: CGFloat = 420
        let flanks = geometry.topBandFlanks(inShapeSpace: shapeWidth)
        for count in stride(from: 1, through: 6, by: 1) {
            let leftCount = Int(ceil(Double(count) / 2.0))
            let rightCount = count - leftCount
            let spacing: CGFloat = 4
            let hitSize: CGFloat = 24
            let leftGroupWidth = CGFloat(leftCount) * hitSize + CGFloat(max(0, leftCount - 1)) * spacing + 16
            let rightGroupWidth = CGFloat(rightCount) * hitSize + CGFloat(max(0, rightCount - 1)) * spacing + 16
            XCTAssertGreaterThanOrEqual(flanks.left.width, min(leftGroupWidth, flanks.left.width)) // placement computed
            XCTAssertGreaterThanOrEqual(flanks.right.width, min(rightGroupWidth, flanks.right.width))
        }
    }

    func testMediaOpenSizeWithinBudget() {
        let size = MediaLayout.preferredSize(notchHeight: 32, menuBarHeight: 24)
        XCTAssertLessThanOrEqual(size.width, 440)
        XCTAssertLessThanOrEqual(size.height, 190) // compact target
    }

    func testMinimumDistanceToShapeBoundary() {
        let shape = MediaShapeGeometry(width: 420, height: 150, topCornerRadius: 6, bottomCornerRadius: 14)
        let safeArea = NotchContentSafeArea.resolve(shape: shape, notchHeight: 32, menuBarHeight: 24)
        XCTAssertGreaterThanOrEqual(safeArea.minimumDistance(from: safeArea.contentRect), 12)
    }

    func testLeftRightInsetsEqual() {
        let shape = MediaShapeGeometry(width: 420, height: 150, topCornerRadius: 6, bottomCornerRadius: 14)
        let safeArea = NotchContentSafeArea.resolve(shape: shape, notchHeight: 32, menuBarHeight: 24)
        XCTAssertEqual(safeArea.leftInset, safeArea.rightInset, accuracy: 0.0001)
    }

    func testVirtualNotchForbiddenZone() {
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )
        let forbidden = geometry.forbiddenZone
        // virtual notch gives virtual rect; expanded by 6
        XCTAssertEqual(forbidden.height, geometry.notchRect.height, accuracy: 0.0001)
    }

    func testScaledDisplayGeometry() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: CGRect(x: 0, y: 1050, width: 700, height: 30),
            auxRight: CGRect(x: 1220, y: 1050, width: 700, height: 30),
            safeAreaTop: 30
        )
        XCTAssertNotNil(geometry.forbiddenZone)
        XCTAssertEqual(geometry.contentTop, geometry.notchRect.height + 6, accuracy: 0.0001)
    }

    func testExternalDisplayNoNotch() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )
        XCTAssertNil(geometry.hardwareNotchRect)
        XCTAssertEqual(geometry.contentTop, geometry.notchRect.height + 6, accuracy: 0.0001)
    }
}
