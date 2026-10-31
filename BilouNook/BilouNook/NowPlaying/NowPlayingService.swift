import AppKit
import Foundation
import Observation

struct NowPlayingPendingSeek: Equatable {
    let target: TimeInterval
    let issuedAt: Date
    let trackIdentity: String
}

@Observable
final class NowPlayingService {
    static let shared = NowPlayingService()

    private(set) var snapshot: NowPlayingSnapshot? {
        didSet { updateLiveActivityState() }
    }
    private(set) var liveActivityState = NowPlayingLiveActivityState.empty
    private(set) var pendingSeek: NowPlayingPendingSeek?
    private(set) var providerName: String = "none"
    private(set) var isRunning = false

    private let seekTolerance: TimeInterval = 1.5
    private let seekTimeout: TimeInterval = 2

    private let providers: [NowPlayingProvider]
    private var activeProvider: NowPlayingProvider?
    private var activeProviderIndex: Int?
    private var failedProviders: Set<ObjectIdentifier> = []
    private var elapsedTimer: Timer?
    private var lastTickAt: Date?
    private var workspaceObserver: NSObjectProtocol?

    private let timerEnabled: Bool
    private let tickInterval: TimeInterval
    private let now: () -> Date
    private let scheduler: NotchScheduler
    private var seekTimeoutHandle: NotchScheduled?

    init(
        providers: [NowPlayingProvider]? = nil,
        timerEnabled: Bool = true,
        tickInterval: TimeInterval = 1,
        now: @escaping () -> Date = Date.init,
        scheduler: NotchScheduler = SystemNotchScheduler()
    ) {
        self.providers = providers ?? Self.defaultProviders()
        self.timerEnabled = timerEnabled
        self.tickInterval = tickInterval
        self.now = now
        self.scheduler = scheduler
    }

    #if DEBUG
    func setSnapshotForTesting(_ snapshot: NowPlayingSnapshot?) {
        self.snapshot = snapshot
    }
    #endif

    var isPlaying: Bool {
        snapshot?.isPlaying ?? false
    }

    var progress: Double {
        snapshot?.progress ?? 0
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        failedProviders.removeAll()
        startWorkspaceObserver()
        startFirstAvailableProvider()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopTimer()
        activeProvider?.stop()
        activeProvider = nil
        activeProviderIndex = nil
        clearPendingSeek()
        providerName = "none"
        snapshot = nil
        removeWorkspaceObserver()
    }

    func togglePlayPause() {
        activeProvider?.send(.togglePlayPause)
    }

    func next() {
        activeProvider?.send(.next)
    }

    func previous() {
        activeProvider?.send(.previous)
    }

    func seek(to seconds: TimeInterval) {
        guard
            let provider = activeProvider,
            let snapshot,
            snapshot.duration > 0,
            seconds.isFinite
        else {
            return
        }

        let target = min(max(0, seconds), snapshot.duration)
        let issuedAt = now()
        clearPendingSeek()
        pendingSeek = NowPlayingPendingSeek(
            target: target,
            issuedAt: issuedAt,
            trackIdentity: snapshot.trackIdentity
        )
        seekTimeoutHandle = scheduler.schedule(after: seekTimeout) { [weak self] in
            self?.clearPendingSeek()
        }

        var optimistic = snapshot
        optimistic.elapsed = target
        optimistic.updatedAt = issuedAt
        self.snapshot = optimistic
        lastTickAt = issuedAt
        provider.send(.seek(target))
    }

    func advanceElapsed(by interval: TimeInterval) {
        guard var snapshot, snapshot.isPlaying, interval > 0 else { return }
        snapshot.elapsed = max(0, snapshot.elapsed + interval)
        if snapshot.duration > 0 {
            snapshot.elapsed = min(snapshot.elapsed, snapshot.duration)
        }
        self.snapshot = snapshot
    }

    static func defaultProviders() -> [NowPlayingProvider] {
        [
            MediaRemoteNowPlayingProvider(),
            AppleScriptNowPlayingProvider(target: .spotify),
            AppleScriptNowPlayingProvider(target: .music),
        ]
    }

    private func firstAvailableProviderIndex() -> Int? {
        providers.indices.first {
            providers[$0].isAvailable && !failedProviders.contains(ObjectIdentifier(providers[$0]))
        }
    }

    private func startFirstAvailableProvider() {
        if let index = firstAvailableProviderIndex() {
            startProvider(at: index)
        } else {
            clearActiveProvider()
        }
    }

    private func startNextProvider(after index: Int) {
        let nextIndex = index + 1
        guard nextIndex < providers.count else {
            clearActiveProvider()
            return
        }
        for candidateIndex in nextIndex..<providers.count where providers[candidateIndex].isAvailable {
            startProvider(at: candidateIndex)
            return
        }
        clearActiveProvider()
    }

    private func startProvider(at index: Int) {
        activeProvider?.stop()
        activeProvider = nil
        activeProviderIndex = nil
        providerName = "none"
        snapshot = nil
        stopTimer()

        let candidate = providers[index]
        guard candidate.isAvailable else {
            startNextProvider(after: index)
            return
        }

        activeProvider = candidate
        activeProviderIndex = index
        providerName = candidate.identifier
        candidate.start(
            onUpdate: { [weak self, weak candidate] snapshot in
                guard
                    let self,
                    let candidate,
                    self.activeProvider === candidate
                else {
                    return
                }
                self.accept(snapshot)
            },
            onFailure: { [weak self, weak candidate] in
                guard
                    let self,
                    let candidate,
                    self.activeProvider === candidate
                else {
                    return
                }
                DispatchQueue.main.async {
                    guard self.activeProvider === candidate else { return }
                    self.failedProviders.insert(ObjectIdentifier(candidate))
                    self.startNextProvider(after: index)
                }
            }
        )
    }

    private func clearActiveProvider() {
        activeProvider?.stop()
        activeProvider = nil
        activeProviderIndex = nil
        clearPendingSeek()
        providerName = "none"
        snapshot = nil
        stopTimer()
    }

    private func accept(_ incoming: NowPlayingSnapshot?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.accept(incoming)
            }
            return
        }

        guard var snapshot = normalized(incoming) else {
            clearPendingSeek()
            self.snapshot = nil
            stopTimer()
            return
        }

        let previous = self.snapshot
        if snapshot.artwork == nil, let previous, previous.trackIdentity == snapshot.trackIdentity {
            snapshot.artwork = previous.artwork
            snapshot.artworkMimeType = previous.artworkMimeType
        }

        if let pendingSeek {
            let age = max(0, now().timeIntervalSince(pendingSeek.issuedAt))
            if snapshot.trackIdentity != pendingSeek.trackIdentity || age > seekTimeout {
                clearPendingSeek()
            } else {
                let expected = pendingSeek.target + (snapshot.isPlaying ? age : 0)
                guard abs(snapshot.elapsed - expected) <= seekTolerance else {
                    return
                }
                clearPendingSeek()
            }
        }

        self.snapshot = snapshot
        lastTickAt = now()
        if snapshot.isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func clearPendingSeek() {
        seekTimeoutHandle?.cancel()
        seekTimeoutHandle = nil
        pendingSeek = nil
    }

    private func updateLiveActivityState() {
        let next = NowPlayingLiveActivityState.from(snapshot)
        guard next != liveActivityState else { return }
        liveActivityState = next
    }

    private func normalized(_ snapshot: NowPlayingSnapshot?) -> NowPlayingSnapshot? {
        guard var snapshot else { return nil }
        snapshot.title = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.artist = snapshot.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.album = snapshot.album.trimmingCharacters(in: .whitespacesAndNewlines)
        guard snapshot.hasContent else { return nil }

        snapshot.elapsed = max(0, snapshot.elapsed)
        snapshot.duration = max(0, snapshot.duration)
        if snapshot.duration > 0 {
            snapshot.elapsed = min(snapshot.elapsed, snapshot.duration)
        }
        return snapshot
    }

    private func startTimer() {
        guard timerEnabled else {
            lastTickAt = now()
            return
        }
        stopTimer()
        lastTickAt = now()
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = self.now()
            let elapsed = current.timeIntervalSince(self.lastTickAt ?? current)
            self.lastTickAt = current
            self.advanceElapsed(by: elapsed)
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func stopTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        lastTickAt = nil
    }

    private func startWorkspaceObserver() {
        guard workspaceObserver == nil else { return }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.clearRecoveredAppleScriptFailures()
            let preferredIndex = self.firstAvailableProviderIndex()
            if let preferredIndex, let activeProviderIndex = self.activeProviderIndex {
                if preferredIndex < activeProviderIndex {
                    self.startProvider(at: preferredIndex)
                }
            } else if self.activeProvider == nil {
                self.startFirstAvailableProvider()
            }
        }
    }

    private func clearRecoveredAppleScriptFailures() {
        for provider in providers {
            guard provider is AppleScriptNowPlayingProvider, provider.isAvailable else { continue }
            failedProviders.remove(ObjectIdentifier(provider))
        }
    }

    private func removeWorkspaceObserver() {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
    }
}
