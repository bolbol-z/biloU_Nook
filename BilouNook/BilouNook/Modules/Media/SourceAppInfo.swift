import AppKit

struct MediaSourceApp {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
}

final class SourceAppInfoCache {
    static let shared = SourceAppInfoCache(loader: SourceAppInfoCache.load)

    private let cache = NSCache<NSString, Entry>()
    private let loader: (String) -> MediaSourceApp?

    init(loader: @escaping (String) -> MediaSourceApp?) {
        self.loader = loader
    }

    func info(for bundleIdentifier: String) -> MediaSourceApp? {
        guard !bundleIdentifier.isEmpty else { return nil }
        let key = bundleIdentifier as NSString
        if let entry = cache.object(forKey: key) {
            return entry.value
        }
        guard let value = loader(bundleIdentifier) else { return nil }
        cache.setObject(Entry(value), forKey: key)
        return value
    }

    private final class Entry {
        let value: MediaSourceApp

        init(_ value: MediaSourceApp) {
            self.value = value
        }
    }

    private static func load(_ bundleIdentifier: String) -> MediaSourceApp? {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }) {
            return MediaSourceApp(
                bundleIdentifier: bundleIdentifier,
                name: app.localizedName ?? bundleIdentifier,
                icon: app.icon
            )
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let bundle = Bundle(url: url)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return MediaSourceApp(
            bundleIdentifier: bundleIdentifier,
            name: name,
            icon: NSWorkspace.shared.icon(forFile: url.path)
        )
    }
}
