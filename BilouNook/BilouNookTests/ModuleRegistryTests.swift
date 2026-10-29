import SwiftUI
import XCTest

private struct StubModule: NotchModule {
    let id: String
    let title: String
    let icon = "circle"
    let preferredSize = CGSize(width: 300, height: 120)
    var isEnabled: Bool = true
    var liveActivityPriority: Int = 0
    var isLiveActivityActive: Bool = false
    var liveActivity: AnyView? = nil

    var expandedView: AnyView {
        AnyView(EmptyView())
    }
}

final class ModuleRegistryTests: XCTestCase {
    func testRegistryPreservesRegistrationOrder() {
        let registry = ModuleRegistry(modules: [
            StubModule(id: "one", title: "One"),
            StubModule(id: "two", title: "Two"),
            StubModule(id: "three", title: "Three"),
        ])

        XCTAssertEqual(registry.modules.map(\.id), ["one", "two", "three"])
        XCTAssertEqual(registry.enabledModules.map(\.id), ["one", "two", "three"])
        XCTAssertEqual(registry.activeModuleID, "one")
    }

    func testDisabledModulesAreHiddenAndSkipped() {
        let registry = ModuleRegistry(modules: [
            StubModule(id: "one", title: "One"),
            StubModule(id: "two", title: "Two", isEnabled: false),
            StubModule(id: "three", title: "Three"),
        ])

        XCTAssertEqual(registry.modules.map(\.id), ["one", "two", "three"])
        XCTAssertEqual(registry.enabledModules.map(\.id), ["one", "three"])

        registry.select(id: "two")
        XCTAssertEqual(registry.activeModuleID, "one")

        registry.selectNext()
        XCTAssertEqual(registry.activeModuleID, "three")

        registry.selectNext()
        XCTAssertEqual(registry.activeModuleID, "one")
    }

    func testDisabledFirstModuleFallsBackToFirstEnabled() {
        let registry = ModuleRegistry(modules: [
            StubModule(id: "one", title: "One", isEnabled: false),
            StubModule(id: "two", title: "Two"),
        ])

        XCTAssertEqual(registry.enabledModules.map(\.id), ["two"])
        XCTAssertEqual(registry.activeModuleID, "two")
        XCTAssertEqual(registry.activeModule?.id, "two")
    }

    func testPreviousWrapsAndDirectionFollowsSelection() {
        let registry = ModuleRegistry(modules: [
            StubModule(id: "one", title: "One"),
            StubModule(id: "two", title: "Two"),
            StubModule(id: "three", title: "Three"),
        ])

        registry.selectPrevious()
        XCTAssertEqual(registry.activeModuleID, "three")
        XCTAssertEqual(registry.transitionDirection, -1)

        registry.select(id: "one")
        XCTAssertEqual(registry.activeModuleID, "one")
        XCTAssertEqual(registry.transitionDirection, -1)

        registry.select(id: "three")
        XCTAssertEqual(registry.activeModuleID, "three")
        XCTAssertEqual(registry.transitionDirection, 1)
    }

    func testLiveActivityUsesHighestActivePriority() {
        let registry = ModuleRegistry(modules: [
            StubModule(
                id: "low",
                title: "Low",
                liveActivityPriority: 1,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("Low"))
            ),
            StubModule(
                id: "high",
                title: "High",
                liveActivityPriority: 10,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("High"))
            ),
        ])

        XCTAssertEqual(registry.activeLiveActivity?.id, "high")
    }

    func testLiveActivityFallsThroughInactiveHigherPriority() {
        let registry = ModuleRegistry(modules: [
            StubModule(
                id: "inactive",
                title: "Inactive",
                liveActivityPriority: 10,
                isLiveActivityActive: false,
                liveActivity: AnyView(Text("Inactive"))
            ),
            StubModule(
                id: "active",
                title: "Active",
                liveActivityPriority: 1,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("Active"))
            ),
        ])

        XCTAssertEqual(registry.activeLiveActivity?.id, "active")
    }

    func testLiveActivityTiesPreserveRegistrationOrder() {
        let registry = ModuleRegistry(modules: [
            StubModule(
                id: "first",
                title: "First",
                liveActivityPriority: 5,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("First"))
            ),
            StubModule(
                id: "second",
                title: "Second",
                liveActivityPriority: 5,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("Second"))
            ),
        ])

        XCTAssertEqual(registry.activeLiveActivity?.id, "first")
    }

    func testDisabledModuleCannotProvideLiveActivity() {
        let registry = ModuleRegistry(modules: [
            StubModule(
                id: "disabled",
                title: "Disabled",
                isEnabled: false,
                liveActivityPriority: 20,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("Disabled"))
            ),
            StubModule(
                id: "enabled",
                title: "Enabled",
                liveActivityPriority: 1,
                isLiveActivityActive: true,
                liveActivity: AnyView(Text("Enabled"))
            ),
        ])

        XCTAssertEqual(registry.activeLiveActivity?.id, "enabled")
    }

    func testInactiveLiveActivitiesReturnNil() {
        let registry = ModuleRegistry(modules: [
            StubModule(
                id: "inactive",
                title: "Inactive",
                liveActivityPriority: 10,
                isLiveActivityActive: false,
                liveActivity: AnyView(Text("Inactive"))
            ),
        ])

        XCTAssertNil(registry.activeLiveActivity)
    }
}
