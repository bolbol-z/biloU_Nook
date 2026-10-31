import AppKit
import SwiftUI
import XCTest

#if DEBUG
@MainActor
final class MediaSnapshotRenderTests: XCTestCase {
    private final class SnapshotProvider: NowPlayingProvider {
        let identifier = "snapshot"
        let isAvailable = true

        private var onUpdate: ((NowPlayingSnapshot?) -> Void)?

        func start(
            onUpdate: @escaping (NowPlayingSnapshot?) -> Void,
            onFailure: @escaping () -> Void
        ) {
            self.onUpdate = onUpdate
        }

        func stop() {
            onUpdate = nil
        }

        func send(_ command: NowPlayingCommand) {}

        func emit(_ snapshot: NowPlayingSnapshot?) {
            onUpdate?(snapshot)
        }
    }

    private final class ProbeBox {
        var frames: [String: CGRect] = [:]
        var timeLabels: [String: [CGRect]] = [:]
    }

    private struct LayoutFixture {
        let id: String
        let shape: MediaShapeGeometry
        let notchHeight: CGFloat
        let menuBarHeight: CGFloat

        var safeArea: NotchContentSafeArea {
            NotchContentSafeArea.resolve(
                shape: shape,
                notchHeight: notchHeight,
                menuBarHeight: menuBarHeight
            )
        }
    }

    private struct StateFixture {
        let id: String
        let snapshot: NowPlayingSnapshot?
    }

    private struct NotchScene {
        let id: String
        let geometry: NotchGeometry
        let panelFrame: CGRect
        let phase: NotchPhase
        let metrics: NotchMetrics
        let showContent: Bool
        let state: StateFixture
        let safeArea: NotchContentSafeArea
    }

    private struct NotchRender {
        let raw: NSBitmapImageRep
        let composite: NSBitmapImageRep
        let annotated: NSBitmapImageRep
    }

    func testRenderRealOpenMediaCompositeToScreensAndReport() throws {
        _ = NSApplication.shared
        let previousModuleID = ModuleRegistry.shared.activeModuleID
        ModuleRegistry.shared.select(id: "media")
        defer {
            if let previousModuleID {
                ModuleRegistry.shared.select(id: previousModuleID)
            }
        }

        let output = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/screens")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let physicalSize = MediaLayout.preferredSize(notchHeight: 32, menuBarHeight: 24)
        let noNotchSize = MediaLayout.preferredSize(notchHeight: 0, menuBarHeight: 24)
        let layouts = [
            LayoutFixture(
                id: "physical-notch",
                shape: MediaShapeGeometry(
                    width: physicalSize.width,
                    height: physicalSize.height,
                    topCornerRadius: 19,
                    bottomCornerRadius: 24
                ),
                notchHeight: 32,
                menuBarHeight: 24
            ),
            LayoutFixture(
                id: "no-notch",
                shape: MediaShapeGeometry(
                    width: noNotchSize.width,
                    height: noNotchSize.height,
                    topCornerRadius: 19,
                    bottomCornerRadius: 24
                ),
                notchHeight: 0,
                menuBarHeight: 24
            ),
        ]

        let now = Date()
        let artwork = makeArtwork()
        let sourceApp = MediaSourceApp(
            bundleIdentifier: "com.spotify.client",
            name: "Spotify",
            icon: makeIcon()
        )
        let browserApp = MediaSourceApp(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            icon: makeIcon()
        )
        let tint = Color(red: 0.18, green: 0.62, blue: 0.46)
        let states = [
            StateFixture(
                id: "01-playing",
                snapshot: snapshot(
                    title: "Midnight City",
                    artist: "M83",
                    album: "Hurry Up, We're Dreaming",
                    artwork: artwork,
                    isPlaying: true,
                    elapsed: 81,
                    duration: 244,
                    updatedAt: now
                )
            ),
            StateFixture(
                id: "02-paused",
                snapshot: snapshot(
                    title: "Midnight City",
                    artist: "M83",
                    album: "Hurry Up, We're Dreaming",
                    artwork: artwork,
                    isPlaying: false,
                    elapsed: 81,
                    duration: 244,
                    updatedAt: now
                )
            ),
            StateFixture(
                id: "03-long-title",
                snapshot: snapshot(
                    title: "The Longest Song Title in the World Keeps Going and Going",
                    artist: "An Artist With a Very Long Name Indeed",
                    album: "An Album With a Substantial Title",
                    artwork: artwork,
                    isPlaying: true,
                    elapsed: 24,
                    duration: 372,
                    updatedAt: now
                )
            ),
            StateFixture(
                id: "05-playing-no-album",
                snapshot: snapshot(
                    title: "Midnight City",
                    artist: "M83",
                    album: "",
                    artwork: artwork,
                    isPlaying: true,
                    elapsed: 81,
                    duration: 244,
                    updatedAt: now
                )
            ),
            StateFixture(
                id: "06-unknown-duration",
                snapshot: snapshot(
                    title: "Midnight City",
                    artist: "M83",
                    album: "Hurry Up, We're Dreaming",
                    artwork: artwork,
                    isPlaying: true,
                    elapsed: 81,
                    duration: 0,
                    updatedAt: now
                )
            ),
            StateFixture(
                id: "07-browser-source",
                snapshot: snapshot(
                    title: "Midnight City",
                    artist: "M83",
                    album: "Hurry Up, We're Dreaming",
                    artwork: artwork,
                    isPlaying: true,
                    elapsed: 81,
                    duration: 244,
                    bundleIdentifier: "com.apple.WebKit.GPU",
                    updatedAt: now
                )
            ),
            StateFixture(id: "08-empty", snapshot: nil),
        ]

        var reportLayouts: [[String: Any]] = []

        for layout in layouts {
            var playingFrames: [String: CGRect] = [:]

            for state in states {
                let (png, frames) = try render(
                    layout: layout,
                    state: state,
                    sourceApp: state.snapshot == nil
                        ? nil
                        : state.id == "07-browser-source" ? browserApp : sourceApp,
                    tint: state.snapshot == nil ? nil : tint
                )

                if state.id == "01-playing" {
                    playingFrames = frames
                }

                let url = output.appendingPathComponent(
                    "\(layout.id)-\(state.id).png"
                )
                try png.write(to: url)
                XCTAssertGreaterThan(png.count, 10_000, "\(url.lastPathComponent) is empty")
                print("[MEDIA SCREEN] \(url.path)")
            }

            reportLayouts.append(
                try report(
                    for: layout,
                    frames: playingFrames
                )
            )
        }

        let reportURL = output.appendingPathComponent("layout-report.json")
        let reportData = try JSONSerialization.data(
            withJSONObject: [
                "panelSize": sizeDictionary(NotchPanel.panelSize()),
                "coordinateSpace": MediaLayout.probeCoordinateSpace,
                "layouts": reportLayouts,
            ],
            options: [.prettyPrinted, .sortedKeys]
        )
        try reportData.write(to: reportURL)
        print("[MEDIA LAYOUT] \(reportURL.path)")
    }

    func testRenderNotchAttachmentCompositeToScreensAndReport() throws {
        _ = NSApplication.shared
        let previousModuleID = ModuleRegistry.shared.activeModuleID
        ModuleRegistry.shared.select(id: "media")
        defer {
            if let previousModuleID {
                ModuleRegistry.shared.select(id: previousModuleID)
            }
        }

        let settings = SettingsStore.shared
        let previousCompact = settings.mediaCompactEnabled
        settings.mediaCompactEnabled = true
        defer { settings.mediaCompactEnabled = previousCompact }

        let previousSharedSnapshot = NowPlayingService.shared.snapshot
        defer { NowPlayingService.shared.setSnapshotForTesting(previousSharedSnapshot) }

        let previousPhase = NotchState.shared.phase
        defer { NotchState.shared.phase = previousPhase }

        let output = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/screens")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let screenFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let physical = NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: CGRect(x: 0, y: 924, width: 646, height: 32),
            auxRight: CGRect(x: 825, y: 924, width: 645, height: 32),
            safeAreaTop: 32
        )
        let noNotch = NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )

        let panelSize = NotchPanel.panelSize()
        let now = Date()
        let artwork = makeArtwork()
        let sourceApp = MediaSourceApp(
            bundleIdentifier: "com.spotify.client",
            name: "Spotify",
            icon: makeIcon()
        )
        let tint = Color(red: 0.18, green: 0.62, blue: 0.46)
        let playing = StateFixture(
            id: "playing",
            snapshot: snapshot(
                title: "Midnight City",
                artist: "M83",
                album: "Hurry Up, We're Dreaming",
                artwork: artwork,
                isPlaying: true,
                elapsed: 81,
                duration: 244,
                updatedAt: now
            )
        )
        let paused = StateFixture(
            id: "paused",
            snapshot: snapshot(
                title: "Midnight City",
                artist: "M83",
                album: "Hurry Up, We're Dreaming",
                artwork: artwork,
                isPlaying: false,
                elapsed: 81,
                duration: 244,
                updatedAt: now
            )
        )
        let longTitle = StateFixture(
            id: "long-title",
            snapshot: snapshot(
                title: "The Longest Song Title in the World Keeps Going and Going",
                artist: "An Artist With a Very Long Name Indeed",
                album: "An Album With a Substantial Title",
                artwork: artwork,
                isPlaying: true,
                elapsed: 24,
                duration: 372,
                updatedAt: now
            )
        )

        let layouts: [(String, NotchGeometry, CGSize)] = [
            ("physical-notch", physical, CGSize(width: 520, height: 225)),
            ("no-notch", noNotch, CGSize(width: 520, height: 217)),
        ]

        var report: [[String: Any]] = []
        for (layoutID, geometry, openSize) in layouts {
            let panelFrame = NotchAttachment.panelFrame(
                screenFrame: screenFrame,
                panelSize: panelSize,
                scale: geometry.backingScaleFactor
            )
            let openMetrics = geometry.openMetrics(for: openSize)
            let safeArea = NotchContentSafeArea.resolve(
                shape: MediaShapeGeometry(openMetrics),
                notchHeight: geometry.isPhysicalNotch ? 32 : 0,
                menuBarHeight: 24
            )
            let closed = geometry.closedMetrics(isLiveActivityActive: false)
            let wings = geometry.closedMetrics(isLiveActivityActive: true)
            let scenes = [
                NotchScene(
                    id: "closed",
                    geometry: geometry,
                    panelFrame: panelFrame,
                    phase: .closed,
                    metrics: closed,
                    showContent: false,
                    state: paused,
                    safeArea: safeArea
                ),
                NotchScene(
                    id: "wings",
                    geometry: geometry,
                    panelFrame: panelFrame,
                    phase: .closed,
                    metrics: wings,
                    showContent: false,
                    state: playing,
                    safeArea: safeArea
                ),
                NotchScene(
                    id: "open-media",
                    geometry: geometry,
                    panelFrame: panelFrame,
                    phase: .open,
                    metrics: openMetrics,
                    showContent: true,
                    state: playing,
                    safeArea: safeArea
                ),
                NotchScene(
                    id: "open-long-title",
                    geometry: geometry,
                    panelFrame: panelFrame,
                    phase: .open,
                    metrics: openMetrics,
                    showContent: true,
                    state: longTitle,
                    safeArea: safeArea
                ),
            ]

            for scene in scenes {
                let rendered = try renderNotchScene(
                    scene,
                    sourceApp: sourceApp,
                    tint: tint
                )
                let url = output.appendingPathComponent("notch-\(layoutID)-\(scene.id).png")
                let png = try pngData(rendered.annotated)
                try png.write(to: url)
                XCTAssertGreaterThan(png.count, 4_000, "\(url.lastPathComponent) is empty")
                print("[NOTCH SCREEN] \(url.path)")

                try assertNotchPixels(
                    scene: scene,
                    rendered: rendered
                )

                if scene.id == "closed" {
                    let cropURL = output.appendingPathComponent("notch-\(layoutID)-corners-4x.png")
                    let crop = try cornerCrop(rendered.composite, scene: scene)
                    try crop.write(to: cropURL)
                    XCTAssertGreaterThan(
                        opaquePixelCount(crop),
                        1_000,
                        "\(cropURL.lastPathComponent) is empty"
                    )
                    print("[NOTCH CORNERS] \(cropURL.path)")
                }
            }

            report.append([
                "id": layoutID,
                "notch": rectDictionary(geometry.notchRect),
                "virtual": rectDictionary(geometry.virtualNotchRect),
                "hardware": geometry.hardwareNotchRect.map(rectDictionary) ?? NSNull(),
                "closed": metricsDictionary(closed),
                "wings": metricsDictionary(wings),
                "open": metricsDictionary(openMetrics),
                "topFlareRadius": geometry.topFlareRadius,
                "bottomRadius": geometry.bottomRadius,
                "overlap": NotchGeometry.overlap,
            ])
        }

        let reportURL = output.appendingPathComponent("notch-report.json")
        let reportData = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]
        )
        try reportData.write(to: reportURL)
        print("[NOTCH REPORT] \(reportURL.path)")
        for entry in report {
            print("[NOTCH METRICS] \(entry)")
        }
    }

    private func renderNotchScene(
        _ scene: NotchScene,
        sourceApp: MediaSourceApp?,
        tint: Color?
    ) throws -> NotchRender {
        let panel = NSPanel(
            contentRect: scene.panelFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false

        let provider = SnapshotProvider()
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()
        if let snapshot = scene.state.snapshot {
            provider.emit(snapshot)
        }
        defer { service.stop() }

        let previousShared = NowPlayingService.shared.snapshot
        NowPlayingService.shared.setSnapshotForTesting(scene.state.snapshot)
        defer { NowPlayingService.shared.setSnapshotForTesting(previousShared) }

        NotchState.shared.phase = scene.phase
        let root = NotchRootView(
            panel: panel,
            previewMetrics: scene.metrics,
            previewShowContent: scene.showContent
        )
        .environment(\.nowPlayingService, service)
        .environment(\.mediaSafeAreaOverride, scene.safeArea)
        .environment(\.mediaSourceAppOverride, sourceApp)
        .environment(\.mediaTintOverride, tint)
        .frame(width: scene.panelFrame.width, height: scene.panelFrame.height)

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: scene.panelFrame.size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.18))
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()

        guard let raw = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw SnapshotError.renderFailed
        }
        host.cacheDisplay(in: host.bounds, to: raw)
        let composite = makeRenderBitmap(
            from: raw,
            hardware: scene.geometry.hardwareNotchRect,
            panelFrame: scene.panelFrame,
            outline: false
        )
        let annotated = makeRenderBitmap(
            from: raw,
            hardware: scene.geometry.hardwareNotchRect,
            panelFrame: scene.panelFrame,
            outline: true
        )
        print(
            "[NOTCH PROBES] \(scene.id) metrics=\(scene.metrics.w)x\(scene.metrics.h) t=\(scene.metrics.t) b=\(scene.metrics.b) pixels=\(raw.pixelsWide)x\(raw.pixelsHigh)"
        )
        return NotchRender(raw: raw, composite: composite, annotated: annotated)
    }

    private func makeRenderBitmap(
        from source: NSBitmapImageRep,
        hardware: CGRect?,
        panelFrame: CGRect,
        outline: Bool
    ) -> NSBitmapImageRep {
        let width = source.pixelsWide
        let height = source.pixelsHigh
        let dest = renderBitmap(width: width, height: height)
        guard let context = NSGraphicsContext(bitmapImageRep: dest) else {
            return dest
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cg = context.cgContext
        cg.setShouldAntialias(false)
        if let image = source.cgImage {
            cg.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        let scale = CGFloat(width) / max(1, panelFrame.width)
        if let hardware {
            let x = (hardware.minX - panelFrame.minX) * scale
            let top = (panelFrame.maxY - hardware.maxY) * scale
            let rect = CGRect(
                x: x,
                y: CGFloat(height) - top - hardware.height * scale,
                width: hardware.width * scale,
                height: hardware.height * scale
            )
            cg.setFillColor(NSColor.black.cgColor)
            cg.fill(rect)
            if outline {
                cg.setStrokeColor(NSColor.magenta.cgColor)
                cg.setLineWidth(1)
                cg.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
            }
        }

        if outline {
            cg.setStrokeColor(NSColor.cyan.cgColor)
            cg.setLineWidth(1)
            cg.move(to: CGPoint(x: 0, y: CGFloat(height) - 0.5))
            cg.addLine(to: CGPoint(x: CGFloat(width), y: CGFloat(height) - 0.5))
            cg.strokePath()
        }
        NSGraphicsContext.restoreGraphicsState()
        return dest
    }

    private func renderBitmap(width: Int, height: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
    }

    private func assertNotchPixels(
        scene: NotchScene,
        rendered: NotchRender
    ) throws {
        let scale = CGFloat(rendered.raw.pixelsWide) / max(1, scene.panelFrame.width)
        let width = rendered.raw.pixelsWide
        let shapeLeft = (scene.panelFrame.width - scene.metrics.w) / 2 * scale
        let shapeRight = shapeLeft + scene.metrics.w * scale

        let topRow = 2
        let topInset = (scene.metrics.t + 2) * scale
        let sampleLeft = Int(ceil(shapeLeft + topInset))
        let sampleRight = Int(floor(shapeRight - topInset))
        XCTAssertLessThan(sampleLeft, sampleRight)
        for x in stride(from: sampleLeft, through: sampleRight, by: max(1, Int(scale))) {
            try assertBlack(rendered.raw, x: x, y: topRow, label: "\(scene.id) top band x=\(x)")
        }

        let silhouette = scene.geometry.hardwareNotchRect == nil ? rendered.raw : rendered.composite
        var firstAlpha: Int?
        var lastAlpha: Int?
        for x in 0..<width {
            guard let color = silhouette.colorAt(x: x, y: 1) else { continue }
            if color.alphaComponent > 0.1 {
                if firstAlpha == nil { firstAlpha = x }
                lastAlpha = x
            }
        }
        let measuredPixels = max(0, (lastAlpha ?? 0) - (firstAlpha ?? 0) + 1)
        let measured = CGFloat(measuredPixels)
        if let hardware = scene.geometry.hardwareNotchRect {
            XCTAssertGreaterThanOrEqual(
                measured,
                hardware.width * scale - 2,
                "\(scene.id) top silhouette is narrower than the hardware notch"
            )

            let hwLeft = (hardware.minX - scene.panelFrame.minX) * scale
            let hwTop = (scene.panelFrame.maxY - hardware.maxY) * scale
            let hwBottom = hwTop + hardware.height * scale
            let hwRight = hwLeft + hardware.width * scale
            let ring: CGFloat = 2
            let x0 = Int(ceil(hwLeft + ring))
            let x1 = Int(floor(hwRight - ring))
            let y0 = Int(ceil(hwTop + ring))
            let y1 = Int(floor(hwBottom - ring))
            XCTAssertLessThan(x0, x1)
            XCTAssertLessThan(y0, y1)
            for x in stride(from: x0, through: x1, by: max(1, Int(scale))) {
                try assertBlack(rendered.composite, x: x, y: y0, label: "\(scene.id) ring bottom")
                try assertBlack(rendered.composite, x: x, y: y1, label: "\(scene.id) ring top")
            }
            for y in stride(from: y0, through: y1, by: max(1, Int(scale))) {
                try assertBlack(rendered.composite, x: x0, y: y, label: "\(scene.id) ring left")
                try assertBlack(rendered.composite, x: x1, y: y, label: "\(scene.id) ring right")
            }
        }

        if scene.id == "wings" {
            XCTAssertGreaterThanOrEqual(
                measured,
                scene.metrics.w * scale - 20 * scale,
                "\(scene.id) wings do not extend beyond the notch"
            )
        }
    }

    private func assertBlack(
        _ bitmap: NSBitmapImageRep,
        x: Int,
        y: Int,
        label: String
    ) throws {
        guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh else {
            XCTFail("\(label) is outside the render")
            return
        }
        guard let color = bitmap.colorAt(x: x, y: y) else {
            XCTFail("\(label) has no pixel")
            return
        }
        XCTAssertGreaterThanOrEqual(color.alphaComponent, 0.98, "\(label) alpha=\(color.alphaComponent)")
        XCTAssertLessThanOrEqual(color.redComponent, 0.03, "\(label) red=\(color.redComponent)")
        XCTAssertLessThanOrEqual(color.greenComponent, 0.03, "\(label) green=\(color.greenComponent)")
        XCTAssertLessThanOrEqual(color.blueComponent, 0.03, "\(label) blue=\(color.blueComponent)")
    }

    private func cornerCrop(
        _ bitmap: NSBitmapImageRep,
        scene: NotchScene
    ) throws -> Data {
        guard let image = bitmap.cgImage else {
            throw SnapshotError.renderFailed
        }
        let notch = scene.geometry.notchRect
        let scale = CGFloat(bitmap.pixelsWide) / max(1, scene.panelFrame.width)
        let x0 = (notch.minX - scene.panelFrame.minX) * scale
        let x1 = (notch.maxX - scene.panelFrame.minX) * scale
        let top = (scene.panelFrame.maxY - notch.maxY) * scale
        let cropWidthPoints: CGFloat = 70
        let cropHeightPoints = min(scene.metrics.h + 20, scene.panelFrame.height)
        let cropWidth = cropWidthPoints * scale
        let cropHeight = cropHeightPoints * scale
        let leftX = max(0, x0 - 22 * scale)
        let rightX = min(CGFloat(bitmap.pixelsWide) - cropWidth, x1 - (cropWidthPoints - 22) * scale)
        let topY = max(0, top)
        let gap: CGFloat = 12 * scale
        let destWidth = Int((cropWidth * 2 + gap) * 2)
        let destHeight = Int(cropHeight * 2)
        let context = CGContext(
            data: nil,
            width: destWidth,
            height: destHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        let leftCrop = CGRect(x: leftX, y: topY, width: cropWidth, height: cropHeight)
        let rightCrop = CGRect(x: rightX, y: topY, width: cropWidth, height: cropHeight)
        if let left = image.cropping(to: leftCrop) {
            context.draw(left, in: CGRect(x: 0, y: 0, width: cropWidth * 2, height: cropHeight * 2))
        }
        if let right = image.cropping(to: rightCrop) {
            context.draw(
                right,
                in: CGRect(
                    x: (cropWidth + gap) * 2,
                    y: 0,
                    width: cropWidth * 2,
                    height: cropHeight * 2
                )
            )
        }
        guard let result = context.makeImage() else {
            throw SnapshotError.renderFailed
        }
        return try pngData(NSBitmapImageRep(cgImage: result))
    }

    private func opaquePixelCount(_ data: Data) -> Int {
        guard let bitmap = NSBitmapImageRep(data: data) else { return 0 }
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.01 {
                    count += 1
                }
            }
        }
        return count
    }

    private func pngData(_ bitmap: NSBitmapImageRep) throws -> Data {
        guard let png = bitmap.representation(
            using: NSBitmapImageRep.FileType.png,
            properties: [:]
        ) else {
            throw SnapshotError.encodingFailed
        }
        return png
    }

    private func metricsDictionary(_ metrics: NotchMetrics) -> [String: Any] {
        [
            "width": metrics.w,
            "height": metrics.h,
            "top": metrics.t,
            "bottom": metrics.b,
        ]
    }

    private func render(
        layout: LayoutFixture,
        state: StateFixture,
        sourceApp: MediaSourceApp?,
        tint: Color?
    ) throws -> (Data, [String: CGRect]) {
        let panelSize = NotchPanel.panelSize()
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false

        let provider = SnapshotProvider()
        let service = NowPlayingService(providers: [provider], timerEnabled: false)
        service.start()
        if let snapshot = state.snapshot {
            provider.emit(snapshot)
        }
        defer { service.stop() }

        let previousPhase = NotchState.shared.phase
        NotchState.shared.phase = .open
        defer { NotchState.shared.phase = previousPhase }

        let probeBox = ProbeBox()
        let root = ZStack {
            NotchRootView(
                panel: panel,
                previewMetrics: NotchMetrics(
                    w: layout.shape.width,
                    h: layout.shape.height,
                    t: layout.shape.topCornerRadius,
                    b: layout.shape.bottomCornerRadius
                ),
                previewShowContent: true
            )
            .environment(\.nowPlayingService, service)
            .environment(\.mediaSafeAreaOverride, layout.safeArea)
            .environment(\.mediaSourceAppOverride, sourceApp)
            .environment(\.mediaTintOverride, tint)
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .coordinateSpace(name: MediaLayout.probeCoordinateSpace)
        .onPreferenceChange(MediaLayoutProbeKey.self) { frames in
            probeBox.frames = Dictionary(
                uniqueKeysWithValues: frames.map { ($0.key.rawValue, $0.value) }
            )
        }
        .onPreferenceChange(MediaTimeLabelProbeKey.self) { labels in
            probeBox.timeLabels = Dictionary(
                uniqueKeysWithValues: labels.map { ($0.key.rawValue, $0.value) }
            )
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: panelSize)
        host.layoutSubtreeIfNeeded()

        let expectedProbes = state.snapshot == nil ? 0 : MediaLayoutProbe.allCases.count
        let deadline = Date().addingTimeInterval(1)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            host.layoutSubtreeIfNeeded()
        } while probeBox.frames.count < expectedProbes && Date() < deadline

        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw SnapshotError.renderFailed
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(
            using: NSBitmapImageRep.FileType.png,
            properties: [:]
        ) else {
            throw SnapshotError.encodingFailed
        }

        print(
            "[MEDIA PROBES] \(layout.id)-\(state.id) snapshot=\(service.snapshot?.title ?? "nil") frames=\(probeBox.frames.keys.sorted())"
        )
        if state.snapshot != nil {
            try validate(
                frames: probeBox.frames,
                timeLabels: probeBox.timeLabels,
                layout: layout
            )
        }
        return (png, probeBox.frames)
    }

    private func validate(
        frames: [String: CGRect],
        timeLabels: [String: [CGRect]],
        layout: LayoutFixture
    ) throws {
        let required: [MediaLayoutProbe] = [
            .artwork,
            .textColumn,
            .title,
            .artist,
            .progressTrack,
            .timeRow,
            .elapsedTime,
            .remainingTime,
            .controls,
        ]
        for probe in required {
            XCTAssertNotNil(frames[probe.rawValue], "Missing \(probe.rawValue) frame")
        }
        for label in MediaTimeLabel.allCases {
            XCTAssertEqual(
                timeLabels[label.rawValue]?.count,
                1,
                "\(layout.id) must render exactly one \(label.rawValue) time label"
            )
        }

        let shapeBounds = CGRect(
            x: (NotchPanel.panelSize().width - layout.shape.width) / 2,
            y: 0,
            width: layout.shape.width,
            height: layout.shape.height
        )
        let safeArea = layout.safeArea

        for (name, frame) in frames {
            let shapeFrame = frame.offsetBy(
                dx: -shapeBounds.minX,
                dy: -shapeBounds.minY
            )
            let checkDistance = {
                XCTAssertGreaterThanOrEqual(
                    safeArea.minimumDistance(from: shapeFrame),
                    13.9,
                    "\(layout.id) \(name) is too close to the shape boundary"
                )
            }
            checkDistance()
            XCTAssertGreaterThanOrEqual(
                shapeFrame.minX,
                safeArea.contentRect.minX - 0.5,
                "\(layout.id) \(name) starts left of the safe area"
            )
            XCTAssertGreaterThanOrEqual(
                shapeFrame.minY,
                safeArea.contentRect.minY - 0.5,
                "\(layout.id) \(name) starts above the safe area"
            )
            XCTAssertLessThanOrEqual(
                shapeFrame.maxX,
                safeArea.contentRect.maxX + 0.5,
                "\(layout.id) \(name) ends right of the safe area"
            )
            XCTAssertLessThanOrEqual(
                shapeFrame.maxY,
                safeArea.contentRect.maxY + 0.5,
                "\(layout.id) \(name) ends below the safe area"
            )
        }

        if let artwork = frames[MediaLayoutProbe.artwork.rawValue] {
            XCTAssertEqual(
                artwork.midY,
                safeArea.contentRect.midY,
                accuracy: 1,
                "\(layout.id) artwork is not centered against the content"
            )
        }

        let left = frames[MediaLayoutProbe.title.rawValue]?.minX ?? 0
        let artworkRight = frames[MediaLayoutProbe.artwork.rawValue]?.maxX ?? 0
        XCTAssertEqual(
            left - artworkRight,
            MediaLayout.metrics.columnSpacing,
            accuracy: 1,
            "\(layout.id) artwork/column gap is wrong"
        )
    }

    private func report(
        for layout: LayoutFixture,
        frames: [String: CGRect]
    ) throws -> [String: Any] {
        let shapeBounds = CGRect(
            x: (NotchPanel.panelSize().width - layout.shape.width) / 2,
            y: 0,
            width: layout.shape.width,
            height: layout.shape.height
        )
        let safeArea = layout.safeArea
        let distances = Dictionary(
            uniqueKeysWithValues: frames.map { name, frame in
                (
                    name,
                    safeArea.minimumDistance(
                        from: frame.offsetBy(
                            dx: -shapeBounds.minX,
                            dy: -shapeBounds.minY
                        )
                    )
                )
            }
        )

        return [
            "id": layout.id,
            "panelSize": sizeDictionary(NotchPanel.panelSize()),
            "shapeBounds": rectDictionary(shapeBounds),
            "topClearance": safeArea.topClearance,
            "sideInset": safeArea.sideInset,
            "bottomInset": safeArea.bottomInset,
            "contentRect": rectDictionary(safeArea.contentRect),
            "leftInset": safeArea.leftInset,
            "rightInset": safeArea.rightInset,
            "frames": Dictionary(
                uniqueKeysWithValues: frames.map { name, frame in
                    (name, rectDictionary(frame))
                }
            ),
            "boundaryDistances": Dictionary(
                uniqueKeysWithValues: distances.map { name, distance in
                    (name, Double(distance))
                }
            ),
        ]
    }

    private func snapshot(
        title: String,
        artist: String,
        album: String,
        artwork: Data?,
        isPlaying: Bool,
        elapsed: TimeInterval,
        duration: TimeInterval,
        bundleIdentifier: String = "com.spotify.client",
        updatedAt: Date
    ) -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            artworkMimeType: artwork == nil ? nil : "image/tiff",
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: duration,
            bundleIdentifier: bundleIdentifier,
            updatedAt: updatedAt
        )
    }

    private func sizeDictionary(_ size: NSSize) -> [String: Any] {
        [
            "width": Double(size.width),
            "height": Double(size.height),
        ]
    }

    private func rectDictionary(_ rect: CGRect) -> [String: Any] {
        [
            "x": Double(rect.minX),
            "y": Double(rect.minY),
            "width": Double(rect.width),
            "height": Double(rect.height),
        ]
    }

    private func makeArtwork() -> Data {
        let size = NSSize(width: 300, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSGradient(
            colors: [
                NSColor(srgbRed: 0.12, green: 0.36, blue: 0.72, alpha: 1),
                NSColor(srgbRed: 0.88, green: 0.32, blue: 0.26, alpha: 1),
            ]
        )?.draw(in: rect, angle: -35)
        NSColor.white.withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: 48, y: 54, width: 204, height: 204)).fill()
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: 106, y: 112, width: 88, height: 88)).fill()
        image.unlockFocus()
        return image.tiffRepresentation ?? Data()
    }

    private func makeIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.lockFocus()
        NSColor(srgbRed: 0.16, green: 0.76, blue: 0.36, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 60, height: 60)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 22, y: 22, width: 20, height: 20)).fill()
        image.unlockFocus()
        return image
    }
}

private enum SnapshotError: Error {
    case renderFailed
    case encodingFailed
}
#endif
