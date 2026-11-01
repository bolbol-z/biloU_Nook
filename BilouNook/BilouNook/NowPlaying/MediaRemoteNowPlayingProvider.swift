import AppKit
import Foundation

final class MediaRemoteNowPlayingProvider: NowPlayingProvider {
    struct Runtime {
        let script: URL
        let framework: URL
    }

    let identifier = "mediaremote"

    private let runtime: Runtime?
    private let fileManager: FileManager
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var lineBuffer = Data()
    private let bufferLock = NSLock()
    private var onUpdate: ((NowPlayingSnapshot?) -> Void)?
    private var onFailure: (() -> Void)?
    private var isStopping = false

    private let controlQueue = DispatchQueue(label: "com.bilou.nowplaying.mediaremote.control")
    private var controlProcess: Process?
    private let controlLock = NSLock()
    private var terminateObserver: NSObjectProtocol?
    private var lastBundleIdentifiers: Set<String> = []

    init(runtime: Runtime? = nil, fileManager: FileManager = .default) {
        self.runtime = runtime ?? Self.bundledRuntime(fileManager: fileManager)
        self.fileManager = fileManager
    }

    var isStreaming: Bool {
        process?.isRunning ?? false
    }

    var isAvailable: Bool {
        guard let runtime else { return false }
        return fileManager.isExecutableFile(atPath: "/usr/bin/perl")
            && fileManager.fileExists(atPath: runtime.script.path)
            && fileManager.fileExists(atPath: runtime.framework.path)
            && fileManager.fileExists(
                atPath: runtime.framework.appendingPathComponent("MediaRemoteAdapter").path
            )
    }

    func start(
        onUpdate: @escaping (NowPlayingSnapshot?) -> Void,
        onFailure: @escaping () -> Void
    ) {
        stop()
        guard isAvailable, let runtime else {
            onFailure()
            return
        }
        self.onUpdate = onUpdate
        self.onFailure = onFailure
        isStopping = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            runtime.script.path,
            runtime.framework.path,
            "stream",
            "--no-diff",
            "--debounce=50",
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.terminationHandler = { [weak self] _ in
            guard let self, !self.isStopping else { return }
            DispatchQueue.main.async {
                self.onFailure?()
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.consume(data)
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            self.onUpdate = nil
            self.onFailure = nil
            DispatchQueue.main.async {
                onFailure()
            }
            return
        }

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        observePlayerTermination()
    }

    func stop() {
        isStopping = true
        onUpdate = nil
        onFailure = nil

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe?.fileHandleForReading.closeFile()
        stderrPipe?.fileHandleForReading.closeFile()

        if let process, process.isRunning {
            process.terminate()
            let deadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < deadline {
                usleep(20_000)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }

        self.process = nil
        stdoutPipe = nil
        stderrPipe = nil
        bufferLock.lock()
        lineBuffer.removeAll()
        bufferLock.unlock()

        controlLock.lock()
        let runningControl = controlProcess
        controlLock.unlock()
        if let runningControl, runningControl.isRunning {
            runningControl.terminate()
        }

        if let terminateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminateObserver)
        }
        terminateObserver = nil
        lastBundleIdentifiers.removeAll()
    }

    func send(_ command: NowPlayingCommand) {
        guard let runtime else { return }
        let arguments: [String]
        switch command {
        case .togglePlayPause:
            arguments = ["send", "2"]
        case .next:
            arguments = ["send", "4"]
        case .previous:
            arguments = ["send", "5"]
        case .seek(let seconds):
            let micros = Int64(max(0, seconds) * 1_000_000)
            arguments = ["seek", String(micros)]
        }
        runControl(arguments: arguments, runtime: runtime)
    }

    static func snapshot(from payload: [String: Any], now: Date = Date()) -> NowPlayingSnapshot? {
        guard !payload.isEmpty else { return nil }
        let title = trimmedString(payload["title"])
        guard !title.isEmpty else { return nil }

        let artwork: Data?
        if let encoded = payload["artworkData"] as? String, !encoded.isEmpty {
            artwork = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters)
        } else {
            artwork = nil
        }

        return NowPlayingSnapshot(
            title: title,
            artist: trimmedString(payload["artist"]),
            album: trimmedString(payload["album"]),
            artwork: artwork,
            artworkMimeType: payload["artworkMimeType"] as? String,
            isPlaying: boolValue(payload["playing"]),
            elapsed: max(0, doubleValue(payload["elapsedTime"])),
            duration: max(0, doubleValue(payload["duration"])),
            bundleIdentifier: payload["bundleIdentifier"] as? String,
            parentApplicationBundleIdentifier: payload["parentApplicationBundleIdentifier"] as? String,
            updatedAt: now
        )
    }

    private func consume(_ data: Data) {
        bufferLock.lock()
        lineBuffer.append(data)
        var lines: [Data] = []
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = Data(lineBuffer[..<newline])
            lineBuffer.removeSubrange(...newline)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        bufferLock.unlock()

        for line in lines {
            handleLine(line)
        }
    }

    private func handleLine(_ line: Data) {
        guard
            let data = try? JSONSerialization.jsonObject(with: line),
            let object = data as? [String: Any],
            let type = object["type"] as? String,
            type == "data",
            let payload = object["payload"] as? [String: Any]
        else {
            return
        }

        let snapshot = Self.snapshot(from: payload)
        let identifiers = Set([
            payload["bundleIdentifier"] as? String,
            payload["parentApplicationBundleIdentifier"] as? String,
        ].compactMap { $0 })
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !identifiers.isEmpty {
                self.lastBundleIdentifiers = identifiers
            }
            self.onUpdate?(snapshot)
        }
    }

    private func observePlayerTermination() {
        if let terminateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminateObserver)
        }
        terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleIdentifier = app.bundleIdentifier,
                self.lastBundleIdentifiers.contains(bundleIdentifier)
            else {
                return
            }
            self.lastBundleIdentifiers.removeAll()
            self.onUpdate?(nil)
        }
    }

    private func runControl(arguments: [String], runtime: Runtime) {
        controlQueue.async { [weak self] in
            guard let self else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [
                runtime.script.path,
                runtime.framework.path,
            ] + arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            self.controlLock.lock()
            self.controlProcess = process
            self.controlLock.unlock()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                // Control is best-effort; the stream remains the source of truth.
            }

            self.controlLock.lock()
            if self.controlProcess === process {
                self.controlProcess = nil
            }
            self.controlLock.unlock()
        }
    }

    private static func bundledRuntime(fileManager: FileManager) -> Runtime? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let directory = resources.appendingPathComponent("NowPlaying", isDirectory: true)
        let script = directory.appendingPathComponent("mediaremote-adapter.pl")
        let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework", isDirectory: true)
        guard fileManager.fileExists(atPath: script.path) else { return nil }
        return Runtime(script: script, framework: framework)
    }

    private static func trimmedString(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? String, let parsed = Double(value) { return parsed }
        return 0
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }
}
