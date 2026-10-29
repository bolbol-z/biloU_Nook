import AppKit
import SwiftUI
import XCTest

final class NotchRootViewRenderTests: XCTestCase {
    @MainActor
    func testOpenNotchRootViewProducesVisiblePixels() throws {
        _ = NSApplication.shared
        let previousPhase = NotchState.shared.phase
        NotchState.shared.phase = .open
        defer { NotchState.shared.phase = previousPhase }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false

        let renderer = ImageRenderer(
            content: NotchRootView(panel: panel)
                .frame(width: 700, height: 320)
        )
        renderer.scale = 1

        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertGreaterThan(image.width, 0)
        XCTAssertGreaterThan(image.height, 0)
        XCTAssertTrue(hasVisiblePixel(image))
    }

    @MainActor
    func testModuleShellProducesVisiblePixels() throws {
        let renderer = ImageRenderer(
            content: ModuleShellView()
                .frame(width: 520, height: 160)
        )
        renderer.scale = 1

        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertGreaterThan(image.width, 0)
        XCTAssertGreaterThan(image.height, 0)
        XCTAssertTrue(hasVisiblePixel(image))
    }

    private func hasVisiblePixel(_ image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for index in stride(from: 3, to: data.count, by: 4) where data[index] > 0 {
            return true
        }
        return false
    }
}
