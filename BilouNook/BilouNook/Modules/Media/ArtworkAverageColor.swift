import AppKit
import CoreGraphics
import Foundation

enum ArtworkAverageColor {
    static func color(from data: Data) -> NSColor? {
        guard let image = ArtworkDecoder.cgImage(from: data, maxPixelSize: 24) else {
            return nil
        }

        let width = 16
        let height = 16
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.05 else { continue }
            red += Double(pixels[index]) / 255 * alpha
            green += Double(pixels[index + 1]) / 255 * alpha
            blue += Double(pixels[index + 2]) / 255 * alpha
            total += alpha
        }
        guard total > 0 else { return nil }

        let color = NSColor(
            srgbRed: red / total,
            green: green / total,
            blue: blue / total,
            alpha: 1
        )
        return normalized(color)
    }

    private static func normalized(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return color }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 1
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(
            hue: hue,
            saturation: min(max(saturation, 0.22), 0.8),
            brightness: min(max(brightness, 0.36), 0.78),
            alpha: alpha
        )
    }
}

final class ArtworkAverageColorCache {
    static let shared = ArtworkAverageColorCache()

    private let cache = NSCache<NSString, NSColor>()

    func cachedTint(identity: String) -> NSColor? {
        cache.object(forKey: identity as NSString)
    }

    func tint(for data: Data, identity: String) -> NSColor? {
        if let cached = cachedTint(identity: identity) {
            return cached
        }
        guard let color = ArtworkAverageColor.color(from: data) else {
            return nil
        }
        cache.setObject(color, forKey: identity as NSString)
        return color
    }
}
