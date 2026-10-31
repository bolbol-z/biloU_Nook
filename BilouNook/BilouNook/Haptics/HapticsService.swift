import AppKit
import os.log

enum HapticKind {
    case open
    case close
}

final class HapticsService {
    static let shared = HapticsService()
    private let logger = OSLog(subsystem: "com.bilou.BilouNook", category: "haptics")
    private var lastFireTime: Date = .distantPast
    private var lastFireKind: HapticKind?
    private var lastFirePattern: NSHapticFeedbackManager.FeedbackPattern?
    
    var callsSinceOpen: Int = 0
    var callsSinceClose: Int = 0
    
    func play(_ kind: HapticKind) {
        if !SettingsStore.shared.hapticsEnabled {
            os_log(.info, log: logger, "SKIP ts=%.6f kind=%{public}@ reason=disabled thread=main", Date().timeIntervalSinceReferenceDate, String(describing: kind))
            return
        }
        let now = Date()
        if let lastKind = lastFireKind, let lastTime = Optional(lastFireTime), now.timeIntervalSince(lastTime) < 0.25 && lastKind == kind {
            os_log(.info, log: logger, "SKIP ts=%.6f kind=%{public}@ reason=same_kind_cooldown250ms thread=main", now.timeIntervalSinceReferenceDate, String(describing: kind))
            return
        }
        if let lastKind = lastFireKind, now.timeIntervalSince(lastFireTime) < 0.12 {
            if (lastKind == .close && kind == .open) || (lastKind == .open && kind == .close) {
                os_log(.info, log: logger, "SKIP ts=%.6f kind=%{public}@ reason=opposite_cooldown120ms thread=main", now.timeIntervalSinceReferenceDate, String(describing: kind))
                return
            }
        }
        let pattern = patternFromString(SettingsStore.shared.hapticPattern)
        lastFireTime = now
        lastFireKind = kind
        lastFirePattern = pattern
        if kind == .open { callsSinceOpen += 1 } else { callsSinceClose += 1 }
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
            os_log(.info, log: self.logger, "PLAY ts=%.6f kind=%{public}@ pattern=%{public}@ trigger=transition caller=HapticsService.play thread=main", now.timeIntervalSinceReferenceDate, String(describing: kind), String(describing: pattern))
        }
    }
    
    private func patternFromString(_ s: String) -> NSHapticFeedbackManager.FeedbackPattern {
        switch s {
        case "generic": return .generic
        case "alignment": return .alignment
        case "levelChange": return .levelChange
        default: return .generic
        }
    }
    
#if DEBUG
    func playOnce(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        if !SettingsStore.shared.hapticsEnabled { return }
        let now = Date()
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
            os_log(.info, log: self.logger, "PLAY ts=%.6f kind=test pattern=%{public}@ trigger=manual caller=HapticsService.playOnce thread=main", now.timeIntervalSinceReferenceDate, String(describing: pattern))
        }
    }
#endif
}
