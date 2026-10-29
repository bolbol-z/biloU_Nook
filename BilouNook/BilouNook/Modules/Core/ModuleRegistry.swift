import SwiftUI

@Observable
final class ModuleRegistry {
    static let shared = ModuleRegistry(modules: [MediaModule(), ModuleA(), ModuleB()])

    private(set) var modules: [any NotchModule]
    private(set) var activeModuleID: String?
    private(set) var transitionDirection: Int = 1

    init(modules: [any NotchModule]) {
        self.modules = modules
        self.activeModuleID = modules.first(where: { $0.isEnabled })?.id
    }

    var enabledModules: [any NotchModule] {
        modules.filter { $0.isEnabled }
    }

    var activeModule: (any NotchModule)? {
        let enabled = enabledModules
        return enabled.first(where: { $0.id == activeModuleID }) ?? enabled.first
    }

    var activeLiveActivity: (any NotchModule)? {
        var selected: (any NotchModule)?
        for module in enabledModules where module.isLiveActivityActive && module.liveActivity != nil {
            if let selected, module.liveActivityPriority <= selected.liveActivityPriority {
                continue
            }
            selected = module
        }
        return selected
    }

    func select(id: String) {
        guard id != activeModuleID else { return }
        guard let index = enabledModules.firstIndex(where: { $0.id == id }) else { return }
        if let current = activeIndex {
            transitionDirection = index >= current ? 1 : -1
        } else {
            transitionDirection = 1
        }
        activeModuleID = id
    }

    func selectNext() {
        let enabled = enabledModules
        guard !enabled.isEmpty else { return }
        guard let current = activeIndex else {
            transitionDirection = 1
            activeModuleID = enabled.first?.id
            return
        }
        transitionDirection = 1
        activeModuleID = enabled[(current + 1) % enabled.count].id
    }

    func selectPrevious() {
        let enabled = enabledModules
        guard !enabled.isEmpty else { return }
        guard let current = activeIndex else {
            transitionDirection = -1
            activeModuleID = enabled.last?.id
            return
        }
        transitionDirection = -1
        activeModuleID = enabled[(current - 1 + enabled.count) % enabled.count].id
    }

    private var activeIndex: Int? {
        enabledModules.firstIndex(where: { $0.id == activeModuleID })
    }
}
