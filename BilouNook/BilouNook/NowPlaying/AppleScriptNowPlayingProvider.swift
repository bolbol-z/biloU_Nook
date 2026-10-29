import AppKit
import Foundation

final class AppleScriptNowPlayingProvider: NowPlayingProvider {
    enum Target {
        case spotify
        case music

        var bundleIdentifier: String {
            switch self {
            case .spotify: return "com.spotify.client"
            case .music: return "com.apple.Music"
            }
        }

        var notificationName: String {
            switch self {
            case .spotify: return "com.spotify.client.PlaybackStateChanged"
            case .music: return "com.apple.Music.playerInfo"
            }
        }

        var identifier: String {
            switch self {
            case .spotify: return "spotify-applescript"
            case .music: return "music-applescript"
            }
        }

        var durationDivisor: Double {
            switch self {
            case .spotify: return 1_000
            case .music: return 1
            }
        }

        var readScript: String {
            switch self {
            case .spotify:
                return """
                tell application "Spotify"
                    if player state is stopped then return ""
                    set t to current track
                    return (player state as text) & "|" & (player position as text) & "|" & (name of t) & "|" & (artist of t) & "|" & (album of t) & "|" & (duration of t as text)
                end tell
                """
            case .music:
                return """
                tell application "Music"
                    if player state is stopped then return ""
                    try
                        set t to current track
                    on error
                        return ""
                    end try
                    return (player state as text) & "|" & (player position as text) & "|" & (name of t) & "|" & (artist of t) & "|" & (album of t) & "|" & (duration of t as text)
                end tell
                """
            }
        }

        var playPauseScript: String {
            switch self {
            case .spotify:
                return "tell application \"Spotify\" to playpause"
            case .music:
                return "tell application \"Music\" to playpause"
            }
        }

        var nextScript: String {
            switch self {
            case .spotify:
                return "tell application \"Spotify\" to next track"
            case .music:
                return "tell application \"Music\" to next track"
            }
        }

        var previousScript: String {
            switch self {
            case .spotify:
                return "tell application \"Spotify\" to previous track"
            case .music:
                return "tell application \"Music\" to previous track"
            }
        }

        func seekScript(seconds: TimeInterval) -> String {
            let value = max(0, seconds)
            switch self {
            case .spotify:
                return "tell application \"Spotify\" to set player position to \(value)"
            case .music:
                return "tell application \"Music\" to set player position to \(value)"
            }
        }
    }

    let target: Target
    let identifier: String

    private let workspace: NSWorkspace
    private let queryQueue = DispatchQueue(label: "com.bilou.nowplaying.applescript")
    private var notificationObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var onUpdate: ((NowPlayingSnapshot?) -> Void)?
    private var onFailure: (() -> Void)?
    private var generation: UInt64 = 0

    init(target: Target, workspace: NSWorkspace = .shared) {
        self.target = target
        self.identifier = target.identifier
        self.workspace = workspace
    }

    var isAvailable: Bool {
        isRunning
    }

    func start(
        onUpdate: @escaping (NowPlayingSnapshot?) -> Void,
        onFailure: @escaping () -> Void
    ) {
        stop()
        self.onUpdate = onUpdate
        self.onFailure = onFailure

        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(target.notificationName),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        terminateObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier == self.target.bundleIdentifier
            else {
                return
            }
            self.generation += 1
            self.onFailure?()
        }

        refresh()
    }

    func stop() {
        if let notificationObserver {
            DistributedNotificationCenter.default().removeObserver(notificationObserver)
        }
        if let terminateObserver {
            workspace.notificationCenter.removeObserver(terminateObserver)
        }
        notificationObserver = nil
        terminateObserver = nil
        generation += 1
        onUpdate = nil
        onFailure = nil
    }

    func send(_ command: NowPlayingCommand) {
        let source: String
        switch command {
        case .togglePlayPause:
            source = target.playPauseScript
        case .next:
            source = target.nextScript
        case .previous:
            source = target.previousScript
        case .seek(let seconds):
            source = target.seekScript(seconds: seconds)
        }
        queryQueue.async { [weak self] in
            self?.run(source: source)
        }
    }

    private var isRunning: Bool {
        workspace.runningApplications.contains { $0.bundleIdentifier == target.bundleIdentifier }
    }

    private func refresh() {
        guard isRunning else {
            generation += 1
            onUpdate?(nil)
            return
        }
        generation += 1
        let generation = generation
        queryQueue.async { [weak self] in
            guard let self else { return }
            let result = self.readSnapshot()
            DispatchQueue.main.async {
                guard self.generation == generation else { return }
                switch result {
                case .success(let snapshot):
                    self.onUpdate?(snapshot)
                case .failure(let failure):
                    if failure.isAuthorizationFailure {
                        self.onFailure?()
                    } else {
                        self.onUpdate?(nil)
                    }
                }
            }
        }
    }

    private func readSnapshot() -> Result<NowPlayingSnapshot?, AppleScriptFailure> {
        let result = run(source: target.readScript)
        switch result {
        case .failure(let failure):
            return .failure(failure)
        case .success(let output):
            let parts = output.components(separatedBy: "|")
            guard parts.count >= 6 else { return .success(nil) }
            let state = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard state == "playing" || state == "paused" else { return .success(nil) }
            let title = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return .success(nil) }
            let elapsed = max(0, Double(parts[1]) ?? 0)
            let duration = max(0, (Double(parts[5]) ?? 0) / target.durationDivisor)
            return .success(NowPlayingSnapshot(
                title: title,
                artist: parts[3].trimmingCharacters(in: .whitespacesAndNewlines),
                album: parts[4].trimmingCharacters(in: .whitespacesAndNewlines),
                isPlaying: state == "playing",
                elapsed: duration > 0 ? min(elapsed, duration) : elapsed,
                duration: duration,
                bundleIdentifier: target.bundleIdentifier
            ))
        }
    }

    @discardableResult
    private func run(source: String) -> Result<String, AppleScriptFailure> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(AppleScriptFailure(number: -1, message: "Unable to compile AppleScript"))
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int ?? -1
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript failed"
            return .failure(AppleScriptFailure(number: number, message: message))
        }
        return .success(descriptor.stringValue ?? "")
    }
}

private struct AppleScriptFailure: Error {
    let number: Int
    let message: String

    var isAuthorizationFailure: Bool {
        number == -1743 || number == -600
    }
}
