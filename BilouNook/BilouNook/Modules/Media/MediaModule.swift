import SwiftUI

struct MediaModule: NotchModule {
    let id = "media"
    let title = "Media"
    let icon = "music.note"
    var preferredSize: CGSize { MediaLayout.livePreferredSize() }
    let liveActivityPriority = 10

    var isLiveActivityActive: Bool {
        SettingsStore.shared.mediaCompactEnabled
            && NowPlayingService.shared.liveActivityState.isPlaying
    }

    var liveActivity: AnyView? {
        AnyView(MediaCompactLiveActivity())
    }

    var expandedView: AnyView {
        AnyView(MediaView())
    }
}
