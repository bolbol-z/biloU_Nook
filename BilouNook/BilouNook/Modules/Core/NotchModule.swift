import SwiftUI

protocol NotchModule: Identifiable {
    var id: String { get }
    var title: String { get }
    var icon: String { get }
    var compactView: AnyView? { get }
    var expandedView: AnyView { get }
    var preferredSize: CGSize { get }
    var isEnabled: Bool { get }
    var liveActivityPriority: Int { get }
    var isLiveActivityActive: Bool { get }
    var liveActivity: AnyView? { get }
}

extension NotchModule {
    var compactView: AnyView? { nil }
    var isEnabled: Bool { true }
    var liveActivityPriority: Int { 0 }
    var isLiveActivityActive: Bool { false }
    var liveActivity: AnyView? { nil }
}
