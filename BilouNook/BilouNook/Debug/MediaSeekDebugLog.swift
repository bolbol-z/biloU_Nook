#if DEBUG
#if DEBUG
import Foundation

enum MediaSeekDebugLog {
    private static let logURL: URL? = {
        guard let library = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        let directory = library.appendingPathComponent("Logs/BilouNook", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("seek.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return url
    }()

    static func begin(
        track: String,
        from: TimeInterval,
        target: TimeInterval,
        service: NowPlayingService
    ) {
        log(
            String(
                format: "[MEDIA SEEK] begin track=%@ from=%.2f target=%.2f duration=%.2f pending=%@",
                track,
                from,
                target,
                service.snapshot?.duration ?? 0,
                service.pendingSeek == nil ? "no" : "yes"
            )
        )

        Task { @MainActor in
            for step in 1...6 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let snapshot = service.snapshot
                log(
                    String(
                        format: "[MEDIA SEEK] +%.1fs elapsed=%.2f playing=%@ pending=%@ provider=%@",
                        Double(step) * 0.5,
                        snapshot?.elapsed ?? 0,
                        snapshot?.isPlaying == true ? "yes" : "no",
                        service.pendingSeek.map { String(format: "%.2f", $0.target) } ?? "no",
                        service.providerName
                    )
                )
            }
        }
    }

    private static func log(_ message: String) {
        print(message)

        guard let logURL else { return }
        let formatter = ISO8601DateFormatter()
        let stamp = formatter.string(from: Date())
        guard let stamped = "\(stamp) \(message)\n".data(using: .utf8) else {
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: stamped)
            try handle.close()
        } catch {
            print("[MEDIA SEEK] log write failed error=\(error.localizedDescription)")
        }
    }
}
#endif

#endif
