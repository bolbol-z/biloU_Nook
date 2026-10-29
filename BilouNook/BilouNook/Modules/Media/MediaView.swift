import SwiftUI

private struct NowPlayingServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue = NowPlayingService.shared
}

private struct MediaSafeAreaOverrideKey: EnvironmentKey {
    static let defaultValue: NotchContentSafeArea? = nil
}

private struct MediaSourceAppOverrideKey: EnvironmentKey {
    static let defaultValue: MediaSourceApp? = nil
}

private struct MediaTintOverrideKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    var nowPlayingService: NowPlayingService {
        get { self[NowPlayingServiceEnvironmentKey.self] }
        set { self[NowPlayingServiceEnvironmentKey.self] = newValue }
    }

    var mediaSafeAreaOverride: NotchContentSafeArea? {
        get { self[MediaSafeAreaOverrideKey.self] }
        set { self[MediaSafeAreaOverrideKey.self] = newValue }
    }

    var mediaSourceAppOverride: MediaSourceApp? {
        get { self[MediaSourceAppOverrideKey.self] }
        set { self[MediaSourceAppOverrideKey.self] = newValue }
    }

    var mediaTintOverride: Color? {
        get { self[MediaTintOverrideKey.self] }
        set { self[MediaTintOverrideKey.self] = newValue }
    }
}

struct MediaView: View {
    @Environment(\.nowPlayingService) private var service
    @Environment(\.mediaSafeAreaOverride) private var safeAreaOverride
    @Environment(\.mediaSourceAppOverride) private var sourceAppOverride
    @Environment(\.mediaTintOverride) private var tintOverride
    @State private var sourceApp: MediaSourceApp?
    @State private var tint: Color?

    var body: some View {
        let state = MediaViewState(snapshot: service.snapshot)
        let presentation = presentation(from: state)
        let safeArea = safeAreaOverride ?? MediaLayout.liveSafeArea()

        ZStack {
            ambientBackground(hasTrack: presentation != nil)

            Group {
                switch state {
                case .empty:
                    emptyState
                case .track(let presentation):
                    trackView(presentation)
                }
            }
            .padding(
                .top,
                max(0, safeArea.topClearance - MediaLayout.shellTabBarHeight)
            )
            .padding(.horizontal, safeArea.sideInset)
            .padding(.bottom, safeArea.bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: metadataKey(for: presentation)) {
            await loadMetadata(for: presentation)
        }
    }

    private var emptyState: some View {
        MediaEmptyStateView()
    }

    private func trackView(_ presentation: MediaPresentation) -> some View {
        MediaContentView(
            presentation: presentation,
            sourceApp: sourceAppOverride ?? sourceApp,
            onSeek: { target in
                let current = MediaPlaybackAnchor(presentation: presentation, now: Date())
                    .elapsed(at: Date(), duration: presentation.duration)
                service.seek(to: target)
                #if DEBUG
                MediaSeekDebugLog.begin(
                    track: presentation.title,
                    from: current,
                    target: target,
                    service: service
                )
                #endif
            },
            onPrevious: {
                let elapsed = MediaPlaybackAnchor(presentation: presentation, now: Date())
                    .elapsed(at: Date(), duration: presentation.duration)
                switch MediaTransport.previousAction(elapsed: elapsed) {
                case .restartTrack:
                    service.seek(to: 0)
                case .previousTrack:
                    service.previous()
                }
            },
            onTogglePlayPause: {
                service.togglePlayPause()
            },
            onNext: {
                service.next()
            }
        )
    }

    private func ambientBackground(hasTrack: Bool) -> some View {
        ZStack {
            Color.black

            if hasTrack, let tint = tintOverride ?? tint {
                RadialGradient(
                    colors: [tint.opacity(MediaLayout.ambientOpacity), Color.clear],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 430
                )

                LinearGradient(
                    colors: [Color.clear, tint.opacity(0.055)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .animation(MediaMotion.tintFade, value: tint)
        .ignoresSafeArea()
    }

    private func presentation(from state: MediaViewState) -> MediaPresentation? {
        guard case .track(let presentation) = state else { return nil }
        return presentation
    }

    private func metadataKey(for presentation: MediaPresentation?) -> String {
        guard let presentation else { return "empty" }
        return "\(presentation.bundleIdentifier)#\(presentation.artworkIdentity)"
    }

    @MainActor
    private func loadMetadata(for presentation: MediaPresentation?) async {
        guard let presentation else {
            sourceApp = nil
            tint = nil
            return
        }

        if presentation.bundleIdentifier.isEmpty {
            sourceApp = nil
        } else {
            sourceApp = SourceAppInfoCache.shared.info(for: presentation.bundleIdentifier)
        }

        guard let artwork = presentation.artwork, !artwork.isEmpty else {
            tint = nil
            return
        }

        let identity = presentation.artworkIdentity
        if let cached = ArtworkAverageColorCache.shared.cachedTint(identity: identity) {
            tint = Color(nsColor: cached)
            return
        }

        tint = nil
        let color = await Task.detached(priority: .utility) {
            ArtworkAverageColorCache.shared.tint(for: artwork, identity: identity)
        }.value
        guard !Task.isCancelled else { return }
        tint = color.map { Color(nsColor: $0) }
    }
}
