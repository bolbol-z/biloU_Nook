import AppKit
import XCTest

@MainActor
final class NotchPanelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        ScreenResolver.shared.preference = .builtIn
    }

    func testPanelLevelIsStrictlyAboveMenuBar() {
        let panel = NotchPanel()
        panel.isReleasedWhenClosed = false

        XCTAssertGreaterThan(panel.level.rawValue, NSWindow.Level.mainMenu.rawValue)
    }

    func testPanelFrameIsAttachedToTargetScreenTop() {
        let panel = NotchPanel()
        panel.isReleasedWhenClosed = false
        let screen = ScreenResolver.shared.targetScreen()

        XCTAssertEqual(panel.frame.maxY, screen.frame.maxY, accuracy: 0.0001)
        XCTAssertEqual(panel.frame.midX, screen.frame.midX, accuracy: 0.0001)
        XCTAssertEqual(panel.frame.width, NotchPanel.panelSize().width, accuracy: 0.0001)
    }

    func testPanelConstrainKeepsRequestedFrameAboveTheScreen() {
        let panel = NotchPanel()
        panel.isReleasedWhenClosed = false
        let screen = ScreenResolver.shared.targetScreen()
        let requested = NSRect(x: 100, y: screen.frame.maxY - 40, width: 680, height: 40)

        XCTAssertEqual(panel.constrainFrameRect(requested, to: screen), requested)
    }

    func testPanelCanJoinEverySpaceWithoutMoving() {
        let panel = NotchPanel()
        panel.isReleasedWhenClosed = false

        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
    }
}
