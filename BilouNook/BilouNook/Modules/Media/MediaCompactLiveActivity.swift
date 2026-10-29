import SwiftUI

struct MediaCompactLiveActivity: View {
    @State private var service = NowPlayingService.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        if settings.mediaCompactEnabled, service.liveActivityState.isPlaying {
            MediaCompactContent(state: service.liveActivityState)
                .equatable()
        }
    }
}

private struct MediaCompactContent: View, Equatable {
    let state: NowPlayingLiveActivityState

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(1, geometry.size.height)
            let artworkSize = min(20, max(4, availableHeight - 6))
            let equalizerHeight = min(14, max(2, availableHeight - 8))

            HStack(spacing: 8) {
                ArtworkThumbnailView(
                    artwork: state.artwork,
                    identity: state.artworkIdentity,
                    displaySize: artworkSize,
                    cornerRadius: min(4, artworkSize / 4)
                )
                Spacer(minLength: 0)
                EqualizerView(isPlaying: state.isPlaying, height: equalizerHeight)
            }
            .padding(.horizontal, 12)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
        }
    }
}
