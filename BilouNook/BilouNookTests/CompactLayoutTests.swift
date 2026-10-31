import AppKit
import XCTest

@MainActor
final class CompactLayoutTests: XCTestCase {
    private let screenFrame = CGRect(x: 0, y: 0, width: 1470, height: 956)

    private var physicalGeometry: NotchGeometry {
        NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: CGRect(x: 0, y: 924, width: 646, height: 32),
            auxRight: CGRect(x: 825, y: 924, width: 645, height: 32),
            safeAreaTop: 32
        )
    }

    func testForbiddenZoneExpandsBySixPoints() {
        let geometry = physicalGeometry
        let forbidden = geometry.forbiddenZone
        let notch = geometry.notchRect
        XCTAssertEqual(forbidden.minX, notch.minX - 6, accuracy: 0.0001)
        XCTAssertEqual(forbidden.width, notch.width + 12, accuracy: 0.0001)
        XCTAssertEqual(forbidden.height, notch.height, accuracy: 0.0001)
    }

    func testPhysicalNotchFlanksUseForbiddenZoneBoundaries() {
        let layout = ModuleTabLayout(
            shapeWidth: 420,
            geometry: physicalGeometry,
            moduleCount: 6
        )
        XCTAssertEqual(layout.leftFlank, CGRect(x: 0, y: 0, width: 115, height: 32))
        XCTAssertEqual(layout.rightFlank, CGRect(x: 306, y: 0, width: 114, height: 32))
        XCTAssertEqual(layout.leftCount, 3)
        XCTAssertEqual(layout.rightCount, 3)
        XCTAssertEqual(layout.frames.first?.minX, 27)
        XCTAssertEqual(layout.frames[2].maxX, 107)
        XCTAssertEqual(layout.frames[3].minX, 314)
    }

    func testPhysicalNotchExactFramesForOneThroughSixModules() {
        let expected: [Int: [CGRect]] = [
            1: [rect(83, 4)],
            2: [rect(83, 4), rect(314, 4)],
            3: [rect(55, 4), rect(83, 4), rect(314, 4)],
            4: [rect(55, 4), rect(83, 4), rect(314, 4), rect(342, 4)],
            5: [rect(27, 4), rect(55, 4), rect(83, 4), rect(314, 4), rect(342, 4)],
            6: [rect(27, 4), rect(55, 4), rect(83, 4), rect(314, 4), rect(342, 4), rect(370, 4)],
        ]
        for count in 1...6 {
            let layout = ModuleTabLayout(
                shapeWidth: 420,
                geometry: physicalGeometry,
                moduleCount: count
            )
            XCTAssertEqual(layout.frames, expected[count, default: []], "n=\(count)")
        }
    }

    func testPhysicalNotchTabsNeverIntersectForbiddenZoneOrEachOther() {
        let shapeWidth: CGFloat = 420
        let forbidden = physicalGeometry.forbiddenZone(inShapeSpace: shapeWidth)
        for count in 1...6 {
            let layout = ModuleTabLayout(
                shapeWidth: shapeWidth,
                geometry: physicalGeometry,
                moduleCount: count
            )
            for frame in layout.frames {
                XCTAssertFalse(frame.intersects(forbidden), "n=\(count) frame=\(frame)")
                XCTAssertEqual(frame.midY, 16, accuracy: 0.0001)
            }
            for pair in zip(layout.frames, layout.frames.dropFirst()) {
                XCTAssertGreaterThanOrEqual(pair.1.minX, pair.0.maxX, "n=\(count)")
            }
        }
    }

    func testNoNotchUsesCenteredVirtualBandStrip() {
        let expected: [Int: [CGRect]] = [
            1: [rect(198, 4)],
            2: [rect(184, 4), rect(212, 4)],
            3: [rect(170, 4), rect(198, 4), rect(226, 4)],
            4: [rect(156, 4), rect(184, 4), rect(212, 4), rect(240, 4)],
            5: [rect(142, 4), rect(170, 4), rect(198, 4), rect(226, 4), rect(254, 4)],
            6: [rect(128, 4), rect(156, 4), rect(184, 4), rect(212, 4), rect(240, 4), rect(268, 4)],
        ]
        for count in 1...6 {
            let layout = ModuleTabLayout(
                shapeWidth: 420,
                geometry: noNotchGeometry,
                moduleCount: count
            )
            XCTAssertEqual(layout.frames, expected[count, default: []], "n=\(count)")
            XCTAssertEqual(layout.leftCount, count)
            XCTAssertEqual(layout.rightCount, 0)
        }
    }

    func testScaledDisplayReducesSpacingBeforeTargets() {
        let layout = ModuleTabLayout(
            shapeWidth: 700,
            geometry: scaledGeometry,
            moduleCount: 6
        )
        XCTAssertEqual(layout.leftSpacing, 2)
        XCTAssertEqual(layout.rightSpacing, 2)
        XCTAssertEqual(
            layout.frames,
            [
                rect(0, 3), rect(26, 3), rect(52, 3),
                rect(624, 3), rect(650, 3), rect(676, 3),
            ]
        )
        let forbidden = scaledGeometry.forbiddenZone(inShapeSpace: 700)
        for frame in layout.frames {
            XCTAssertFalse(frame.intersects(forbidden))
        }
    }

    func testExternalDisplayUsesCenteredVirtualBandStrip() {
        let noNotch = ModuleTabLayout(
            shapeWidth: 420,
            geometry: noNotchGeometry,
            moduleCount: 3
        )
        let external = ModuleTabLayout(
            shapeWidth: 420,
            geometry: externalGeometry,
            moduleCount: 3
        )
        XCTAssertEqual(noNotch.frames, [rect(170, 4), rect(198, 4), rect(226, 4)])
        XCTAssertEqual(external.frames, noNotch.frames)
    }

    func testModuleTabSnapshotsToScreens() throws {
        let output = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/screens")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let scenarios: [(String, NotchGeometry, CGFloat)] = [
            ("physical-notch", physicalGeometry, 420),
            ("no-notch", noNotchGeometry, 420),
            ("scaled-display", scaledGeometry, 700),
            ("external-display", externalGeometry, 420),
        ]
        for (name, geometry, shapeWidth) in scenarios {
            for count in 1...6 {
                let png = try tabSnapshot(
                    name: name,
                    geometry: geometry,
                    shapeWidth: shapeWidth,
                    moduleCount: count
                )
                let url = output.appendingPathComponent("module-tabs-\(name)-n\(count).png")
                try png.write(to: url)
                XCTAssertGreaterThan(png.count, 1_000, url.lastPathComponent)
                print("[MODULE TABS] \(url.path)")
            }
        }
    }

    func testContentTopIsNotchHeightPlusSix() {
        let geometry = physicalGeometry
        XCTAssertEqual(geometry.contentTop, geometry.notchRect.height + 6, accuracy: 0.0001)
    }

    func testMediaOpenSizeWithinBudget() {
        let size = MediaLayout.preferredSize(notchHeight: 32, menuBarHeight: 24)
        XCTAssertLessThanOrEqual(size.width, 440)
        XCTAssertLessThanOrEqual(size.height, 190) // compact target
    }

    func testMinimumDistanceToShapeBoundary() {
        let shape = MediaShapeGeometry(width: 420, height: 150, topCornerRadius: 6, bottomCornerRadius: 14)
        let safeArea = NotchContentSafeArea.resolve(shape: shape, notchHeight: 32, menuBarHeight: 24)
        XCTAssertGreaterThanOrEqual(safeArea.minimumDistance(from: safeArea.contentRect), 12)
    }

    func testLeftRightInsetsEqual() {
        let shape = MediaShapeGeometry(width: 420, height: 150, topCornerRadius: 6, bottomCornerRadius: 14)
        let safeArea = NotchContentSafeArea.resolve(shape: shape, notchHeight: 32, menuBarHeight: 24)
        XCTAssertEqual(safeArea.leftInset, safeArea.rightInset, accuracy: 0.0001)
    }

    func testVirtualNotchForbiddenZone() {
        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )
        let forbidden = geometry.forbiddenZone
        // virtual notch gives virtual rect; expanded by 6
        XCTAssertEqual(forbidden.height, geometry.notchRect.height, accuracy: 0.0001)
    }

    func testScaledDisplayGeometry() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: CGRect(x: 0, y: 1050, width: 700, height: 30),
            auxRight: CGRect(x: 1220, y: 1050, width: 700, height: 30),
            safeAreaTop: 30
        )
        XCTAssertNotNil(geometry.forbiddenZone)
        XCTAssertEqual(geometry.contentTop, geometry.notchRect.height + 6, accuracy: 0.0001)
    }

    func testExternalDisplayNoNotch() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )
        XCTAssertNil(geometry.hardwareNotchRect)
        XCTAssertEqual(geometry.contentTop, geometry.notchRect.height + 6, accuracy: 0.0001)
    }
    private var noNotchGeometry: NotchGeometry {
        NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 2,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )
    }

    private var scaledGeometry: NotchGeometry {
        NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: CGRect(x: 0, y: 1050, width: 700, height: 30),
            auxRight: CGRect(x: 1220, y: 1050, width: 700, height: 30),
            safeAreaTop: 30
        )
    }

    private var externalGeometry: NotchGeometry {
        NotchGeometry(
            screenFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
            backingScaleFactor: 1,
            auxLeft: nil,
            auxRight: nil,
            safeAreaTop: 0
        )
    }

    private func rect(_ x: CGFloat, _ y: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: 24, height: 24)
    }

    private func tabSnapshot(
        name: String,
        geometry: NotchGeometry,
        shapeWidth: CGFloat,
        moduleCount: Int
    ) throws -> Data {
        let imageSize = NSSize(width: 820, height: 150)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageSize.width),
            pixelsHigh: Int(imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw SnapshotError.encodingFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(calibratedWhite: 0.06, alpha: 1).setFill()
        NSRect(origin: .zero, size: imageSize).fill()

        let scale = min(1, 740 / max(1, shapeWidth))
        let shapeRect = NSRect(
            x: 40,
            y: 42,
            width: shapeWidth * scale,
            height: max(32, geometry.notchRect.height) * scale + 44
        )
        NSColor.black.setFill()
        NSBezierPath(roundedRect: shapeRect, xRadius: 6, yRadius: 14).fill()

        let shapeOriginX = geometry.screenFrame.midX - shapeWidth / 2
        if let hardware = geometry.hardwareNotchRect {
            let hardwareX = (hardware.minX - shapeOriginX) * scale
            let hardwareRect = NSRect(
                x: shapeRect.minX + hardwareX,
                y: shapeRect.maxY - hardware.height * scale,
                width: hardware.width * scale,
                height: hardware.height * scale
            )
            NSColor.magenta.withAlphaComponent(0.42).setFill()
            hardwareRect.fill()
            NSColor.magenta.withAlphaComponent(0.9).setStroke()
            let border = NSBezierPath(rect: hardwareRect)
            border.lineWidth = 1
            border.stroke()
        }

        let layout = ModuleTabLayout(
            shapeWidth: shapeWidth,
            geometry: geometry,
            moduleCount: moduleCount
        )
        for frame in layout.frames {
            let tabRect = NSRect(
                x: shapeRect.minX + frame.minX * scale,
                y: shapeRect.maxY - frame.maxY * scale,
                width: frame.width * scale,
                height: frame.height * scale
            )
            NSColor.cyan.withAlphaComponent(0.28).setFill()
            tabRect.fill()
            NSColor.cyan.withAlphaComponent(0.95).setStroke()
            let outline = NSBezierPath(roundedRect: tabRect, xRadius: 6, yRadius: 6)
            outline.lineWidth = 1
            outline.stroke()
        }

        let label = "\(name) n=\(moduleCount)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
        ]
        label.draw(at: NSPoint(x: 40, y: 14), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodingFailed
        }
        return png
    }

}

private enum SnapshotError: Error {
    case encodingFailed
}
