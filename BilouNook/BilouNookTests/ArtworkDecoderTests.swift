import AppKit
import XCTest

final class ArtworkDecoderTests: XCTestCase {
    func testThumbnailIsBoundedByRequestedPixelSize() throws {
        let data = try pngData(width: 200, height: 100)
        let image = try XCTUnwrap(ArtworkDecoder.thumbnail(from: data, maxPixelSize: 64))

        XCTAssertLessThanOrEqual(image.size.width, 64)
        XCTAssertLessThanOrEqual(image.size.height, 64)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testInvalidDataReturnsNil() {
        XCTAssertNil(ArtworkDecoder.thumbnail(from: Data([1, 2, 3]), maxPixelSize: 64))
        XCTAssertNil(ArtworkDecoder.thumbnail(from: Data(), maxPixelSize: 64))
    }

    func testInvalidPixelSizeReturnsNil() throws {
        let data = try pngData(width: 10, height: 10)
        XCTAssertNil(ArtworkDecoder.thumbnail(from: data, maxPixelSize: 0))
    }

    private func pngData(width: Int, height: Int) throws -> Data {
        let bitmap = try XCTUnwrap(
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
            )
        )
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
