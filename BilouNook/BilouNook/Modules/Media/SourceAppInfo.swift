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

    func info(
        for bundleIdentifier: String,
        parentBundleIdentifier: String? = nil
    ) -> MediaSourceApp? {
        guard let preferred = Self.preferredBundleIdentifier(
            bundleIdentifier,
            parentBundleIdentifier: parentBundleIdentifier
        ) else {
            return nil
        }
        let key = preferred as NSString
        if let entry = cache.object(forKey: key) {
            return entry.value
        }
        guard let value = loader(preferred) else { return nil }
        cache.setObject(Entry(value), forKey: key)
        return value
    }

    static func preferredBundleIdentifier(
        _ bundleIdentifier: String,
        parentBundleIdentifier: String? = nil
    ) -> String? {
        let parent = parentBundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !parent.isEmpty { return parent }

        let bundle = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundle.isEmpty else { return nil }
        if bundle.hasPrefix("com.apple.WebKit.") { return "com.apple.Safari" }
        if let helperRange = bundle.range(of: ".helper", options: .caseInsensitive) {
            let main = String(bundle[..<helperRange.lowerBound])
            if !main.isEmpty { return main }
        }
        return bundle
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
            return MediaSourceApp(
                bundleIdentifier: bundleIdentifier,
                name: bundleIdentifier,
                icon: NSWorkspace.shared.icon(forFileType: "app")
            )
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
