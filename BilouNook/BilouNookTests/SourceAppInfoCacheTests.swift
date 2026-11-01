import AppKit
import XCTest

final class SourceAppInfoCacheTests: XCTestCase {
    func testRepeatedBundleLookupUsesOneLoaderCall() {
        var calls = 0
        let cache = SourceAppInfoCache { bundleIdentifier in
            calls += 1
            return MediaSourceApp(
                bundleIdentifier: bundleIdentifier,
                name: "Spotify",
                icon: NSImage(size: NSSize(width: 18, height: 18))
            )
        }

        let first = cache.info(for: "com.spotify.client")
        let second = cache.info(for: "com.spotify.client")

        XCTAssertEqual(first?.name, "Spotify")
        XCTAssertEqual(second?.name, "Spotify")
        XCTAssertEqual(calls, 1)
    }

    func testDifferentBundleIdentifiersUseSeparateLookups() {
        var calls = 0
        let cache = SourceAppInfoCache { bundleIdentifier in
            calls += 1
            return MediaSourceApp(
                bundleIdentifier: bundleIdentifier,
                name: bundleIdentifier,
                icon: nil
            )
        }

        _ = cache.info(for: "com.apple.Music")
        _ = cache.info(for: "com.spotify.client")

        XCTAssertEqual(calls, 2)
    }

    func testParentBundleIdentifierTakesPrecedence() {
        var requested: [String] = []
        let cache = SourceAppInfoCache { bundleIdentifier in
            requested.append(bundleIdentifier)
            return MediaSourceApp(
                bundleIdentifier: bundleIdentifier,
                name: bundleIdentifier,
                icon: nil
            )
        }

        let info = cache.info(
            for: "com.apple.WebKit.GPU",
            parentBundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(info?.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(requested, ["com.apple.Safari"])
    }

    func testWebKitFallbackResolvesToSafari() {
        let cache = SourceAppInfoCache { bundleIdentifier in
            MediaSourceApp(bundleIdentifier: bundleIdentifier, name: bundleIdentifier, icon: nil)
        }

        XCTAssertEqual(
            cache.info(for: "com.apple.WebKit.GPU")?.bundleIdentifier,
            "com.apple.Safari"
        )
    }

    func testHelperFallbackResolvesToMainApplication() {
        let cache = SourceAppInfoCache { bundleIdentifier in
            MediaSourceApp(bundleIdentifier: bundleIdentifier, name: bundleIdentifier, icon: nil)
        }

        XCTAssertEqual(
            cache.info(for: "com.spotify.client.helper")?.bundleIdentifier,
            "com.spotify.client"
        )
    }

    func testParentAndFallbackShareOneCachedLookup() {
        var calls = 0
        let cache = SourceAppInfoCache { bundleIdentifier in
            calls += 1
            return MediaSourceApp(bundleIdentifier: bundleIdentifier, name: "Safari", icon: nil)
        }

        _ = cache.info(for: "com.apple.WebKit.GPU", parentBundleIdentifier: "com.apple.Safari")
        _ = cache.info(for: "com.apple.WebKit.GPU")

        XCTAssertEqual(calls, 1)
    }

    func testMissingApplicationIsNotCachedAsAValue() {
        var calls = 0
        let cache = SourceAppInfoCache { _ in
            calls += 1
            return nil
        }

        XCTAssertNil(cache.info(for: "com.example.missing"))
        XCTAssertNil(cache.info(for: "com.example.missing"))
        XCTAssertEqual(calls, 2)
    }
}
