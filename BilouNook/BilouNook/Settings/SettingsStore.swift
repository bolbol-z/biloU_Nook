import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    @Published var fineTuneWidth: Double {
        didSet { UserDefaults.standard.set(fineTuneWidth, forKey: "fineTuneWidth") }
    }
    @Published var fineTuneHeight: Double {
        didSet { UserDefaults.standard.set(fineTuneHeight, forKey: "fineTuneHeight") }
    }
    @Published var topFlareRadius: Double {
        didSet { UserDefaults.standard.set(topFlareRadius, forKey: "topFlareRadius") }
    }
    @Published var bottomRadius: Double {
        didSet { UserDefaults.standard.set(bottomRadius, forKey: "bottomRadius") }
    }
    @Published var openOnHover: Bool {
        didSet { UserDefaults.standard.set(openOnHover, forKey: "openOnHover") }
    }
    @Published var hoverIntentDelay: Double {
        didSet { UserDefaults.standard.set(hoverIntentDelay, forKey: "hoverIntentDelay") }
    }
    @Published var closeDelay: Double {
        didSet { UserDefaults.standard.set(closeDelay, forKey: "closeDelay") }
    }
    @Published var minStateDwell: Double {
        didSet { UserDefaults.standard.set(minStateDwell, forKey: "minStateDwell") }
    }
    @Published var verticalGesturesEnabled: Bool {
        didSet { UserDefaults.standard.set(verticalGesturesEnabled, forKey: "verticalGesturesEnabled") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var mediaCompactEnabled: Bool {
        didSet { UserDefaults.standard.set(mediaCompactEnabled, forKey: "mediaCompactEnabled") }
    }
    @Published var hotPaddingX: Double {
        didSet { UserDefaults.standard.set(hotPaddingX, forKey: "hotPaddingX") }
    }
    @Published var hotPaddingBelow: Double {
        didSet { UserDefaults.standard.set(hotPaddingBelow, forKey: "hotPaddingBelow") }
    }
    @Published var flyByGuardEnabled: Bool {
        didSet { UserDefaults.standard.set(flyByGuardEnabled, forKey: "flyByGuardEnabled") }
    }
    @Published var flyBySpeedThreshold: Double {
        didSet { UserDefaults.standard.set(flyBySpeedThreshold, forKey: "flyBySpeedThreshold") }
    }
    @Published var slowMotion: Bool {
        didSet { UserDefaults.standard.set(slowMotion, forKey: "slowMotion") }
    }
    
    @Published var hapticPattern: String {
        didSet { UserDefaults.standard.set(hapticPattern, forKey: "hapticPattern") }
    }

    init() {
        self.fineTuneWidth = UserDefaults.standard.object(forKey: "fineTuneWidth") as? Double ?? 0
        self.fineTuneHeight = UserDefaults.standard.object(forKey: "fineTuneHeight") as? Double ?? 0
        self.topFlareRadius = UserDefaults.standard.object(forKey: "topFlareRadius") as? Double ?? 0
        self.bottomRadius = UserDefaults.standard.object(forKey: "bottomRadius") as? Double ?? 0
        self.openOnHover = UserDefaults.standard.object(forKey: "openOnHover") as? Bool ?? true
        self.hoverIntentDelay = UserDefaults.standard.object(forKey: "hoverIntentDelay") as? Double ?? 0.0
        self.closeDelay = UserDefaults.standard.object(forKey: "closeDelay") as? Double ?? 0.0
        self.minStateDwell = UserDefaults.standard.object(forKey: "minStateDwell") as? Double ?? 0.0
        self.verticalGesturesEnabled = UserDefaults.standard.object(forKey: "verticalGesturesEnabled") as? Bool ?? true
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        self.mediaCompactEnabled = UserDefaults.standard.object(forKey: "mediaCompactEnabled") as? Bool ?? true
        self.hotPaddingX = UserDefaults.standard.object(forKey: "hotPaddingX") as? Double ?? 14
        self.hotPaddingBelow = UserDefaults.standard.object(forKey: "hotPaddingBelow") as? Double ?? 4
        self.flyByGuardEnabled = UserDefaults.standard.object(forKey: "flyByGuardEnabled") as? Bool ?? false
        self.flyBySpeedThreshold = UserDefaults.standard.object(forKey: "flyBySpeedThreshold") as? Double ?? 2.5
        self.slowMotion = UserDefaults.standard.bool(forKey: "slowMotion")
        self.hapticPattern = UserDefaults.standard.string(forKey: "hapticPattern") ?? "generic"
    }
}
