import XCTest

final class SettingsStoreTests: XCTestCase {
    func testDeadSettingsAreRemoved() {
        let labels = Set(Mirror(reflecting: SettingsStore.shared).children.compactMap(\.label))
        XCTAssertTrue(labels.contains("_fineTuneWidth"))

        let removed = [
            "_handlerEnabled",
            "_handlerWidth",
            "_handlerHeight",
            "_displayMode",
            "_contentInDelay",
            "_contentStagger",
            "_scrubPause",
            "_scrubProgress",
            "_openHapticPattern",
            "_closeHapticPattern",
            "_contentScale_ASSUMPTION",
            "_contentBlur_ASSUMPTION",
            "_contentAnchorY_ASSUMPTION"
        ]
        for label in removed {
            XCTAssertFalse(labels.contains(label), "\(label) should no longer be persisted")
        }
    }
}
