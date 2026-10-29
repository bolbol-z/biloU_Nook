import AppKit
import ImageIO
import SwiftUI

enum ArtworkDecoder {
    static func cgImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0 else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func thumbnail(from data: Data, maxPixelSize: Int) -> NSImage? {
        guard let image = cgImage(from: data, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

final class ArtworkThumbnailCache {
    static let shared = ArtworkThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for data: Data, identity: String, maxPixelSize: Int) -> NSImage? {
        let key = "\(identity)#\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = ArtworkDecoder.thumbnail(from: data, maxPixelSize: maxPixelSize) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct ArtworkThumbnailView: View {
    let artwork: Data?
    let identity: String
    let displaySize: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "music.note")
                .font(.system(size: max(8, displaySize * 0.36), weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))

            ArtworkImageLayer(
                artwork: artwork,
                identity: identity,
                pixelSize: pixelSize
            )
            .id(identity)
            .transition(.opacity)
        }
        .frame(width: displaySize, height: displaySize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(
            MediaMotion.respectingReduceMotion(MediaMotion.artworkSpring, reduceMotion: reduceMotion),
            value: identity
        )
    }

    private var pixelSize: Int {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return max(1, Int((displaySize * scale).rounded(.up)))
    }
}

private struct ArtworkImageLayer: View {
    let artwork: Data?
    let identity: String
    let pixelSize: Int

    @State private var image: NSImage?

    init(artwork: Data?, identity: String, pixelSize: Int) {
        self.artwork = artwork
        self.identity = identity
        self.pixelSize = pixelSize
        let initial: NSImage?
        if let artwork, !artwork.isEmpty {
            initial = ArtworkThumbnailCache.shared.thumbnail(
                for: artwork,
                identity: identity,
                maxPixelSize: pixelSize
            )
        } else {
            initial = nil
        }
        _image = State(initialValue: initial)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: identity) {
            guard let artwork, !artwork.isEmpty else {
                image = nil
                return
            }
            image = ArtworkThumbnailCache.shared.thumbnail(
                for: artwork,
                identity: identity,
                maxPixelSize: pixelSize
            )
        }
    }
}
