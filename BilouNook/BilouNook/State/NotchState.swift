import Foundation
import AppKit
import Combine

enum NotchPhase: Equatable {
    case closed
    case peek
    case open
    case opening
    case closing
}

enum OpenTrigger {
    case hover
    case click
    case gesture
    case programmatic
}

enum CloseReason {
    case mouseLeft
    case gesture
    case click
    case programmatic
    case watchdog
    case system
}

protocol NotchClock: AnyObject {
    func now() -> Date
}

final class SystemNotchClock: NotchClock {
    func now() -> Date { Date() }
}

final class NotchScheduled {
    private let cancelBlock: () -> Void
    private(set) var isCancelled = false

    init(cancel: @escaping () -> Void) {
        self.cancelBlock = cancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        cancelBlock()
    }
}

protocol NotchScheduler: AnyObject {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> NotchScheduled
}

final class SystemNotchScheduler: NotchScheduler {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> NotchScheduled {
        let item = DispatchWorkItem(block: action)
        let scheduled = NotchScheduled { item.cancel() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return scheduled
    }
}

@Observable
final class NotchState {
    static let shared = NotchState()
    
    var phase: NotchPhase = .closed
    var intentDelay: Double = 0.0
    var closeDelay: Double = 0.0
    var minStateDwell: Double = 0.0
    
    private let clock: NotchClock
    private let scheduler: NotchScheduler
    private var closeHandle: NotchScheduled?
    private var intentHandle: NotchScheduled?
    private var outsideSince: Date?
    private var generation: UInt64 = 0
    private var lastCloseTime: Date = .distantPast
    private var lastOpenTime: Date = .distantPast

    init(clock: NotchClock = SystemNotchClock(), scheduler: NotchScheduler = SystemNotchScheduler()) {
        self.clock = clock
        self.scheduler = scheduler
    }
    
    func requestOpen(trigger: OpenTrigger) {
        if phase == .open || phase == .opening {
            debugLog("requestOpen REJECTED trigger=\(trigger) reason=already_open phase=\(phase)")
            return
        }
        if phase == .closing {
            if clock.now().timeIntervalSince(lastCloseTime) < minStateDwell {
                debugLog("requestOpen REJECTED trigger=\(trigger) reason=closing_dwell phase=\(phase)")
                return
            }
        }
        cancelPending()
        generation += 1
        let _gen = generation
        HapticsService.shared.play(.open)
        HapticsService.shared.callsSinceOpen = 1
        phase = .opening
        debugLog("requestOpen ACCEPTED trigger=\(trigger) target=open")
        phase = .open
        lastOpenTime = clock.now()
    }
    
    func requestClose(reason: CloseReason) {
        if phase == .closed || phase == .closing {
            debugLog("requestClose REJECTED reason=\(reason) phase=\(phase)")
            return
        }
        if clock.now().timeIntervalSince(lastOpenTime) < minStateDwell {
            debugLog("requestClose REJECTED reason=\(reason) phase=\(phase) cause=dwell")
            return
        }
        cancelPending()
        generation += 1
        let gen = generation
        HapticsService.shared.play(.close)
        HapticsService.shared.callsSinceClose = 1
        phase = .closing
        lastCloseTime = clock.now()
        outsideSince = nil
        debugLog("requestClose ACCEPTED reason=\(reason)")
        closeHandle = scheduler.schedule(after: closeDelay) { [weak self] in
            guard let self, self.generation == gen else { return }
            if self.phase == .closing {
                self.phase = .closed
            }
        }
    }
    
    func closeImmediately(reason: CloseReason) {
        requestClose(reason: reason)
    }
    
    func enterIntent() {
        if phase == .open || phase == .opening { return }
        if phase == .closing && clock.now().timeIntervalSince(lastCloseTime) < minStateDwell { return }
        cancelPending()
        generation += 1
        let gen = generation
        if intentDelay <= 0 {
            requestOpen(trigger: .hover)
            return
        }
        intentHandle = scheduler.schedule(after: intentDelay) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.requestOpen(trigger: .hover)
        }
    }
    
    func cancelIntent() {
        intentHandle?.cancel()
        intentHandle = nil
    }
    
    func cancelPending() {
        closeHandle?.cancel()
        closeHandle = nil
        intentHandle?.cancel()
        intentHandle = nil
    }

    func watchdogTick(isOutside: Bool) {
        if phase == .closed || !isOutside {
            outsideSince = nil
            return
        }
        let now = clock.now()
        guard let since = outsideSince else {
            outsideSince = now
            return
        }
        let elapsed = now.timeIntervalSince(since)
        guard elapsed >= 0.5 else { return }
        outsideSince = nil
        debugLog(String(format: "watchdog close outsideSince=%.2f", elapsed))
        closeImmediately(reason: .watchdog)
    }
    
    func toggle() {
        cancelPending()
        if phase == .open || phase == .opening {
            closeImmediately(reason: .click)
        } else {
            requestOpen(trigger: .click)
        }
    }
    
    func close() {
        closeImmediately(reason: .programmatic)
    }
    
    func open() {
        requestOpen(trigger: .programmatic)
    }
    
    func scheduleClose() {
        requestClose(reason: .mouseLeft)
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        MouseLog.write(message)
        #endif
    }
}
