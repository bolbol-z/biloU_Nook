import SwiftUI

struct MediaContentView: View {
    let presentation: MediaPresentation
    let sourceApp: MediaSourceApp?
    let onSeek: (TimeInterval) -> Void
    let onPrevious: () -> Void
    let onTogglePlayPause: () -> Void
    let onNext: () -> Void
    let previewDragFraction: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        presentation: MediaPresentation,
        sourceApp: MediaSourceApp? = nil,
        onSeek: @escaping (TimeInterval) -> Void = { _ in },
        onPrevious: @escaping () -> Void = {},
        onTogglePlayPause: @escaping () -> Void = {},
        onNext: @escaping () -> Void = {},
        previewDragFraction: Double? = nil
    ) {
        self.presentation = presentation
        self.sourceApp = sourceApp
        self.onSeek = onSeek
        self.onPrevious = onPrevious
        self.onTogglePlayPause = onTogglePlayPause
        self.onNext = onNext
        self.previewDragFraction = previewDragFraction
    }

    private var metrics: MediaLayoutMetrics { MediaLayout.metrics }

    var body: some View {
        HStack(alignment: .center, spacing: metrics.columnSpacing) {
            artwork
            rightColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var artwork: some View {
        ZStack(alignment: .bottomTrailing) {
            ArtworkThumbnailView(
                artwork: presentation.artwork,
                identity: presentation.artworkIdentity,
                displaySize: metrics.artworkSize,
                cornerRadius: metrics.artworkCornerRadius
            )
            .shadow(color: Color.black.opacity(0.38), radius: 14, y: 6)
            .scaleEffect(presentation.isPlaying ? 1 : 0.92)
            .animation(
                MediaMotion.respectingReduceMotion(MediaMotion.artworkSpring, reduceMotion: reduceMotion),
                value: presentation.isPlaying
            )

            if let sourceApp {
                SourceAppBadge(app: sourceApp, size: metrics.sourceBadgeSize)
                    .padding(3)
                    .transition(.opacity)
            }
        }
        .frame(width: metrics.artworkSize, height: metrics.artworkSize)
        #if DEBUG
        .mediaLayoutProbe(.artwork)
        #endif
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: MediaLayout.titleToArtist) {
                    MarqueeText(
                        text: presentation.title.isEmpty ? "Unknown Track" : presentation.title,
                        font: .system(size: 15, weight: .semibold, design: .rounded),
                        color: .white,
                        height: MediaLayout.titleHeight
                    )
                    #if DEBUG
                    .mediaLayoutProbe(.title)
                    #endif

                    let secondary = secondaryLine
                    MarqueeText(
                        text: secondary.isEmpty ? (presentation.artist.isEmpty ? "Unknown Artist" : presentation.artist) : secondary,
                        font: .system(size: 12, weight: .medium, design: .rounded),
                        color: Color.white.opacity(0.7),
                        height: MediaLayout.artistHeight
                    )
                    #if DEBUG
                    .mediaLayoutProbe(.artist)
                    #endif
                }
                .id(presentation.trackIdentity)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 5)),
                        removal: .opacity.combined(with: .offset(y: -5))
                    )
                )
            }
            .frame(
                height: MediaLayout.titleHeight
                    + MediaLayout.titleToArtist
                    + MediaLayout.artistHeight,
                alignment: .topLeading
            )
            .clipped()
            .animation(
                MediaMotion.respectingReduceMotion(MediaMotion.trackChange, reduceMotion: reduceMotion),
                value: presentation.trackIdentity
            )

            Spacer()
                .frame(height: MediaLayout.artistToProgress)

            MediaProgressBar(
                presentation: presentation,
                onSeek: onSeek,
                previewDragFraction: previewDragFraction
            )

            Spacer()
                .frame(height: MediaLayout.progressToTimes)

            timeRow

            Spacer()
                .frame(height: MediaLayout.timesToControls)

            controls
        }
        .frame(height: MediaLayout.contentHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if DEBUG
        .mediaLayoutProbe(.textColumn)
        #endif
    }

    private var secondaryLine: String {
        let artist = presentation.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = presentation.album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artist.isEmpty && !album.isEmpty {
            return "\(artist) · \(album)"
        }
        if !artist.isEmpty {
            return artist
        }
        if !album.isEmpty {
            return album
        }
        return ""
    }

    private var timeRow: some View {
        HStack {
            Text(timeString(presentation.elapsed))
                .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.6))
            Spacer()
            Text(timeString(presentation.duration))
                .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.6))
        }
        .frame(height: MediaLayout.timeRowHeight)
        .frame(maxWidth: .infinity)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        guard interval.isFinite else { return "--:--" }
        let total = Int(max(0, interval))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            MediaControlButton(
                systemName: "backward.fill",
                symbolSize: MediaLayout.transportSymbolSize,
                hitSize: 34,
                label: "Previous track",
                action: onPrevious
            )

            MediaControlButton(
                systemName: presentation.playPauseSymbol,
                symbolSize: MediaLayout.playSymbolSize,
                hitSize: MediaLayout.controlHitSize,
                emphasized: true,
                label: presentation.isPlaying ? "Pause" : "Play",
                action: onTogglePlayPause
            )

            MediaControlButton(
                systemName: "forward.fill",
                symbolSize: MediaLayout.transportSymbolSize,
                hitSize: 34,
                label: "Next track",
                action: onNext
            )

            Spacer(minLength: 0)
        }
        .frame(height: MediaLayout.controlsHeight)
        #if DEBUG
        .mediaLayoutProbe(.controls)
        #endif
    }
}

struct MediaEmptyStateView: View {
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "music.note")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.48))

            Text("Nothing playing")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.84))

            Text("Start playback in Spotify, Music, or a browser.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SourceAppBadge: View {
    let app: MediaSourceApp
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.88))
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)

            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size * 0.78, height: size * 0.78)
                    .clipShape(Circle())
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(app.name)
    }
}

private struct MediaControlButton: View {
    let systemName: String
    let symbolSize: CGFloat
    let hitSize: CGFloat
    var emphasized = false
    let label: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if emphasized {
                    Circle()
                        .fill(Color.white.opacity(isHovering ? 0.22 : 0.12))
                        .frame(width: 38, height: 38)
                        .animation(
                            MediaMotion.respectingReduceMotion(MediaMotion.controlSpring, reduceMotion: reduceMotion),
                            value: isHovering
                        )
                } else {
                    Circle()
                        .fill(Color.white.opacity(isHovering ? 0.1 : 0))
                        .frame(width: 34, height: 34)
                        .animation(
                            MediaMotion.respectingReduceMotion(MediaMotion.controlSpring, reduceMotion: reduceMotion),
                            value: isHovering
                        )
                }

                Image(systemName: systemName)
                    .font(.system(size: symbolSize, weight: emphasized ? .bold : .semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(width: max(hitSize, 34), height: max(hitSize, 34))
            .contentShape(Rectangle())
        }
        .buttonStyle(MediaControlPressStyle(reduceMotion: reduceMotion))
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct MediaControlPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(
                MediaMotion.respectingReduceMotion(MediaMotion.controlSpring, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}
