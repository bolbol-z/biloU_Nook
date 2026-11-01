import XCTest

private final class FakeNowPlayingProvider: NowPlayingProvider {
    let identifier: String
    var isAvailable: Bool

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var sentCommands: [NowPlayingCommand] = []
    private var onUpdate: ((NowPlayingSnapshot?) -> Void)?
    private var onFailure: (() -> Void)?

    init(identifier: String, isAvailable: Bool = true) {
        self.identifier = identifier
        self.isAvailable = isAvailable
    }

    func start(
        onUpdate: @escaping (NowPlayingSnapshot?) -> Void,
        onFailure: @escaping () -> Void
    ) {
        startCount += 1
        self.onUpdate = onUpdate
        self.onFailure = onFailure
    }

    func stop() {
        stopCount += 1
    }

    func send(_ command: NowPlayingCommand) {
        sentCommands.append(command)
    }

    func emit(_ snapshot: NowPlayingSnapshot?) {
        onUpdate?(snapshot)
    }

    func fail() {
        onFailure?()
    }
}

@MainActor
final class NowPlayingServiceTests: XCTestCase {
    private func makeSnapshot(
        title: String = "Song",
        artist: String = "Artist",
        album: String = "Album",
        artwork: Data? = nil,
        isPlaying: Bool = true,
        elapsed: TimeInterval = 10,
        duration: TimeInterval = 100
    ) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            artworkMimeType: artwork == nil ? nil : "image/jpeg",
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: duration,
            bundleIdentifier: "com.example.player",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    func testUsesFirstAvailableProvider() {
        let unavailable = FakeNowPlayingProvider(identifier: "unavailable", isAvailable: false)
        let primary = FakeNowPlayingProvider(identifier: "primary")
        let secondary = FakeNowPlayingProvider(identifier: "secondary")
        let service = NowPlayingService(
            providers: [unavailable, primary, secondary],
            timerEnabled: false
        )

        service.start()

        XCTAssertEqual(service.providerName, "primary")
        XCTAssertEqual(primary.startCount, 1)
        XCTAssertEqual(secondary.startCount, 0)
        XCTAssertEqual(unavailable.startCount, 0)

        service.stop()
        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(service.snapshot, nil)
    }

    func testFallsBackWhenActiveProviderFails() {
        let primary = FakeNowPlayingProvider(identifier: "primary")
        let secondary = FakeNowPlayingProvider(identifier: "secondary")
        let service = NowPlayingService(
            providers: [primary, secondary],
            timerEnabled: false
        )
        service.start()
        XCTAssertEqual(service.providerName, "primary")

        primary.fail()
        settle()

        XCTAssertEqual(service.providerName, "secondary")
        XCTAssertEqual(primary.stopCount, 1)
        XCTAssertEqual(secondary.startCount, 1)
        service.stop()
    }

    func testElapsedAdvancesOnlyWhilePlaying() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        provider.emit(makeSnapshot(isPlaying: true, elapsed: 10, duration: 100))
        service.advanceElapsed(by: 2.5)
        XCTAssertEqual(service.snapshot?.elapsed, 12.5)

        provider.emit(makeSnapshot(isPlaying: false, elapsed: 12.5, duration: 100))
        service.advanceElapsed(by: 5)
        XCTAssertEqual(service.snapshot?.elapsed, 12.5)
        XCTAssertEqual(service.progress, 0.125, accuracy: 0.0001)
        service.stop()
    }

    func testLiveActivityStateIgnoresElapsedChanges() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        provider.emit(makeSnapshot(elapsed: 10, duration: 100))
        let liveState = service.liveActivityState
        service.advanceElapsed(by: 2.5)

        XCTAssertEqual(service.snapshot?.elapsed, 12.5)
        XCTAssertEqual(service.liveActivityState, liveState)
        service.stop()
    }

    func testLiveActivityStateTracksPlaybackTrackAndArtwork() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        provider.emit(makeSnapshot(title: "A", isPlaying: true))
        XCTAssertTrue(service.liveActivityState.isPlaying)
        XCTAssertEqual(service.liveActivityState.trackIdentity, makeSnapshot(title: "A").trackIdentity)
        XCTAssertNil(service.liveActivityState.artwork)

        provider.emit(makeSnapshot(title: "A", isPlaying: false))
        XCTAssertFalse(service.liveActivityState.isPlaying)

        let artwork = Data([1, 2, 3, 4])
        provider.emit(makeSnapshot(title: "B", artwork: artwork, isPlaying: true))
        XCTAssertEqual(service.liveActivityState.trackIdentity, makeSnapshot(title: "B").trackIdentity)
        XCTAssertEqual(service.liveActivityState.artwork, artwork)
        service.stop()

        XCTAssertEqual(service.liveActivityState, .empty)
    }

    func testElapsedClampsAtDuration() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        provider.emit(makeSnapshot(elapsed: 99, duration: 100))
        service.advanceElapsed(by: 5)
        XCTAssertEqual(service.snapshot?.elapsed, 100)
        service.stop()
    }

    func testArtworkIsPreservedForSameTrackAndClearedForNewTrack() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()
        let artwork = Data([1, 2, 3, 4])

        provider.emit(makeSnapshot(title: "A", artwork: artwork))
        provider.emit(makeSnapshot(title: "A", artwork: nil))
        XCTAssertEqual(service.snapshot?.artwork, artwork)
        XCTAssertEqual(service.snapshot?.artworkMimeType, "image/jpeg")

        provider.emit(makeSnapshot(title: "B", artwork: nil))
        XCTAssertNil(service.snapshot?.artwork)
        XCTAssertNil(service.snapshot?.artworkMimeType)
        service.stop()
    }

    func testRapidTrackChangesKeepLatestSnapshot() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        for index in 0..<50 {
            provider.emit(makeSnapshot(title: "Track \(index)"))
        }

        XCTAssertEqual(service.snapshot?.title, "Track 49")
        service.stop()
    }

    func testNilSnapshotClearsPlayer() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        provider.emit(makeSnapshot())
        XCTAssertNotNil(service.snapshot)
        provider.emit(nil)
        XCTAssertNil(service.snapshot)
        service.stop()
    }

    func testCommandsForwardToActiveProvider() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()
        provider.emit(makeSnapshot())

        service.togglePlayPause()
        service.next()
        service.previous()
        service.seek(to: 42)

        XCTAssertEqual(provider.sentCommands, [
            .togglePlayPause,
            .next,
            .previous,
            .seek(42),
        ])
        service.stop()
    }

    func testNoAvailableProviderReportsNone() {
        let unavailable = FakeNowPlayingProvider(identifier: "unavailable", isAvailable: false)
        let service = NowPlayingService(providers: [unavailable], timerEnabled: false)

        service.start()
        XCTAssertEqual(service.providerName, "none")
        XCTAssertNil(service.snapshot)
        service.stop()
    }

    func testEmptyMetadataIsIgnored() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()

        provider.emit(NowPlayingSnapshot(title: "   "))
        XCTAssertNil(service.snapshot)
        service.stop()
    }
}


final class MediaRemoteNowPlayingProviderTests: XCTestCase {
    func testSnapshotParsesArtworkAndPlayback() {
        let payload: [String: Any] = [
            "title": "Song",
            "artist": "Artist",
            "album": "Album",
            "artworkData": Data([1, 2, 3]).base64EncodedString(),
            "artworkMimeType": "image/png",
            "playing": true,
            "elapsedTime": 12.5,
            "duration": 100.0,
            "bundleIdentifier": "com.example.player",
        ]

        let snapshot = MediaRemoteNowPlayingProvider.snapshot(from: payload)

        XCTAssertEqual(snapshot?.title, "Song")
        XCTAssertEqual(snapshot?.artist, "Artist")
        XCTAssertEqual(snapshot?.album, "Album")
        XCTAssertEqual(snapshot?.artwork, Data([1, 2, 3]))
        XCTAssertEqual(snapshot?.artworkMimeType, "image/png")
        XCTAssertEqual(snapshot?.isPlaying, true)
        XCTAssertEqual(snapshot?.elapsed, 12.5)
        XCTAssertEqual(snapshot?.duration, 100)
        XCTAssertEqual(snapshot?.bundleIdentifier, "com.example.player")
        XCTAssertNil(snapshot?.parentApplicationBundleIdentifier)
    }

    func testSnapshotCarriesParentApplicationBundleIdentifier() {
        let payload: [String: Any] = [
            "title": "Live Stream",
            "bundleIdentifier": "com.apple.WebKit.GPU",
            "parentApplicationBundleIdentifier": "com.apple.Safari",
            "playing": false,
        ]

        let snapshot = MediaRemoteNowPlayingProvider.snapshot(from: payload)

        XCTAssertEqual(snapshot?.bundleIdentifier, "com.apple.WebKit.GPU")
        XCTAssertEqual(snapshot?.parentApplicationBundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(snapshot?.sourceBundleIdentifier, "com.apple.Safari")
    }

    func testSnapshotRejectsEmptyOrUntitledPayload() {
        XCTAssertNil(MediaRemoteNowPlayingProvider.snapshot(from: [:]))
        XCTAssertNil(MediaRemoteNowPlayingProvider.snapshot(from: ["playing": true]))
        XCTAssertNil(MediaRemoteNowPlayingProvider.snapshot(from: ["title": "   "]))
    }

    func testStopTerminatesStreamingHelper() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NowPlayingTests-\(UUID().uuidString)", isDirectory: true)
        let framework = directory.appendingPathComponent("MediaRemoteAdapter.framework", isDirectory: true)
        let binary = framework.appendingPathComponent("MediaRemoteAdapter")
        let script = directory.appendingPathComponent("mediaremote-adapter.pl")
        try FileManager.default.createDirectory(at: framework, withIntermediateDirectories: true)
        try Data().write(to: binary)
        try "sleep 60\n".write(to: script, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = MediaRemoteNowPlayingProvider(
            runtime: .init(script: script, framework: framework)
        )
        provider.start(onUpdate: { _ in }, onFailure: {})
        XCTAssertTrue(provider.isStreaming)

        provider.stop()
        XCTAssertFalse(provider.isStreaming)
    }
}

@MainActor
final class NowPlayingPendingSeekTests: XCTestCase {
    private func makeSnapshot(
        elapsed: TimeInterval,
        duration: TimeInterval = 100,
        isPlaying: Bool = true,
        title: String = "Song"
    ) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: title,
            artist: "Artist",
            album: "Album",
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: duration,
            bundleIdentifier: "com.example.player",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }

    func testSeekSetsOptimisticPositionAndPendingState() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let issuedAt = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { issuedAt }
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))

        service.seek(to: 50)

        XCTAssertEqual(service.snapshot?.elapsed, 50)
        XCTAssertEqual(service.pendingSeek?.target, 50)
        XCTAssertEqual(service.pendingSeek?.issuedAt, issuedAt)
        XCTAssertEqual(provider.sentCommands, [.seek(50)])
        service.stop()
    }

    func testStaleProviderPositionIsRejectedWhilePending() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let issuedAt = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { issuedAt }
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))
        service.seek(to: 50)

        provider.emit(makeSnapshot(elapsed: 10))

        XCTAssertNotNil(service.pendingSeek)
        XCTAssertEqual(service.snapshot?.elapsed, 50)
        service.stop()
    }

    func testConfirmationClearsPendingAndAcceptsPosition() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let issuedAt = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { issuedAt.addingTimeInterval(0.4) }
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))
        service.seek(to: 50)

        provider.emit(makeSnapshot(elapsed: 50.4))

        XCTAssertNil(service.pendingSeek)
        XCTAssertEqual(service.snapshot?.elapsed, 50.4)
        service.stop()
    }

    func testTimeoutAcceptsNextProviderPositionAsReal() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        var currentDate = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { currentDate }
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))
        service.seek(to: 50)

        currentDate = currentDate.addingTimeInterval(2.1)
        provider.emit(makeSnapshot(elapsed: 10))

        XCTAssertNil(service.pendingSeek)
        XCTAssertEqual(service.snapshot?.elapsed, 10)
        service.stop()
    }

    func testSilentProviderClearsPendingAfterTimeoutAndAcceptsNextPosition() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let scheduler = NotchStateTestScheduler()
        var currentDate = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { currentDate },
            scheduler: scheduler
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))
        service.seek(to: 50)

        currentDate = currentDate.addingTimeInterval(2)
        scheduler.advance(by: 2)

        XCTAssertNil(service.pendingSeek)
        provider.emit(makeSnapshot(elapsed: 10))
        XCTAssertEqual(service.snapshot?.elapsed, 10)
        service.stop()
    }

    func testConfirmationCancelsSeekTimeout() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let scheduler = NotchStateTestScheduler()
        let issuedAt = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { issuedAt.addingTimeInterval(0.4) },
            scheduler: scheduler
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))
        service.seek(to: 50)
        provider.emit(makeSnapshot(elapsed: 50.4))
        XCTAssertNil(service.pendingSeek)

        scheduler.advance(by: 10)
        provider.emit(makeSnapshot(elapsed: 10))

        XCTAssertEqual(service.snapshot?.elapsed, 10)
        service.stop()
    }

    func testTrackChangeClearsPendingSeekAndCancelsTimeout() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let scheduler = NotchStateTestScheduler()
        let issuedAt = Date(timeIntervalSince1970: 2_000)
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { issuedAt },
            scheduler: scheduler
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10))
        service.seek(to: 50)

        provider.emit(makeSnapshot(elapsed: 0, title: "Next Song"))

        XCTAssertNil(service.pendingSeek)
        scheduler.advance(by: 10)
        XCTAssertEqual(service.snapshot?.title, "Next Song")
        service.stop()
    }

    func testUnsupportedSeekDoesNotEnterPendingOrSendCommand() {
        let provider = FakeNowPlayingProvider(identifier: "fake")
        let service = NowPlayingService(
            providers: [provider],
            timerEnabled: false,
            now: { Date(timeIntervalSince1970: 2_000) }
        )
        service.start()
        provider.emit(makeSnapshot(elapsed: 10, duration: 0))

        service.seek(to: 30)

        XCTAssertNil(service.pendingSeek)
        XCTAssertEqual(service.snapshot?.elapsed, 10)
        XCTAssertTrue(provider.sentCommands.isEmpty)
        service.stop()
    }
}
