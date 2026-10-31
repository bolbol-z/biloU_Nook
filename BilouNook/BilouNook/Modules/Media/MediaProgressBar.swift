import AppKit
import SwiftUI

struct MediaProgressBar: View {
    let presentation: MediaPresentation
    let onSeek: (TimeInterval) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchor: MediaPlaybackAnchor
    @State private var dragFraction: Double?
    @State private var isHovering = false

    init(
        presentation: MediaPresentation,
        onSeek: @escaping (TimeInterval) -> Void,
        previewDragFraction: Double? = nil
    ) {
        self.presentation = presentation
        self.onSeek = onSeek
        _anchor = State(initialValue: MediaPlaybackAnchor(presentation: presentation, now: Date()))
        _dragFraction = State(initialValue: previewDragFraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MediaLayout.progressToTimes) {
            track
                .frame(height: MediaLayout.progressHitHeight)
                #if DEBUG
                .mediaLayoutProbe(.progressTrack)
                #endif

            timeRow
                .frame(height: MediaLayout.timeRowHeight)
                #if DEBUG
                .mediaLayoutProbe(.timeRow)
                #endif
        }
        .onChange(of: presentation.trackIdentity) { _, _ in refreshAnchor() }
        .onChange(of: presentation.updatedAt) { _, _ in refreshAnchor() }
        .onChange(of: presentation.isPlaying) { _, _ in refreshAnchor() }
        .onChange(of: presentation.duration) { _, _ in refreshAnchor() }
        .onChange(of: presentation.isSeekable) { _, isSeekable in
            if !isSeekable {
                dragFraction = nil
                popCursorIfNeeded()
            }
        }
        .onDisappear {
            popCursorIfNeeded()
        }
    }

    private var track: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: !presentation.isPlaying && dragFraction == nil
            )
        ) { context in
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                let fraction = displayedFraction(at: context.date)
                let thumbX = min(max(fraction * width, 5), width - 5)
                let expanded = presentation.isSeekable && (isHovering || dragFraction != nil)
                let trackHeight = expanded ? MediaLayout.expandedTrackHeight : MediaLayout.trackHeight

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: width, height: trackHeight)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: max(0, fraction * width), height: trackHeight)
                        .frame(maxHeight: .infinity, alignment: .center)

                    if expanded {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 11, height: 11)
                            .position(x: thumbX, y: geometry.size.height / 2)

                        Text(MediaFormatting.time(displayedElapsed(at: context.date)))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Color.black.opacity(0.84))
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(Capsule().fill(Color.white.opacity(0.94)))
                            .fixedSize()
                            .position(
                                x: min(max(thumbX, 24), width - 24),
                                y: -10
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(seekGesture(width: width))
                .onHover { inside in
                    guard presentation.isSeekable else { return }
                    guard inside != isHovering else { return }
                    isHovering = inside
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue(MediaFormatting.time(displayedElapsed(at: Date())))
        .accessibilityAdjustableAction { direction in
            guard presentation.isSeekable else { return }
            let step = max(1, presentation.duration * 0.02)
            let current = displayedElapsed(at: Date())
            switch direction {
            case .increment:
                onSeek(min(presentation.duration, current + step))
            case .decrement:
                onSeek(max(0, current - step))
            @unknown default:
                break
            }
        }
    }

    private var timeRow: some View {
        HStack(spacing: 0) {
            Text(presentation.isSeekable ? MediaFormatting.time(displayedElapsed(at: Date())) : "--:--")
                .accessibilityIdentifier("media.elapsed")
                #if DEBUG
                .mediaLayoutProbe(.elapsedTime)
                .mediaTimeLabelProbe(.elapsed)
                #endif
            Spacer(minLength: 8)
            Text(
                presentation.isSeekable
                    ? MediaFormatting.remaining(
                        elapsed: displayedElapsed(at: Date()),
                        duration: presentation.duration
                    )
                    : "--:--"
            )
            .accessibilityIdentifier("media.remaining")
            #if DEBUG
            .mediaLayoutProbe(.remainingTime)
            .mediaTimeLabelProbe(.remaining)
            #endif
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Color.white.opacity(0.55))
    }

    private func displayedFraction(at date: Date) -> Double {
        guard presentation.duration > 0 else { return 0 }
        if let dragFraction {
            return min(max(dragFraction, 0), 1)
        }
        return anchor.progress(duration: presentation.duration, at: date)
    }

    private func displayedElapsed(at date: Date) -> TimeInterval {
        guard presentation.duration > 0 else { return 0 }
        if let dragFraction {
            return presentation.duration * min(max(dragFraction, 0), 1)
        }
        return anchor.elapsed(at: date, duration: presentation.duration)
    }

    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard presentation.isSeekable else { return }
                dragFraction = clampedFraction(value.location.x, width: width)
            }
            .onEnded { value in
                guard presentation.isSeekable else {
                    dragFraction = nil
                    return
                }
                let fraction = clampedFraction(value.location.x, width: width)
                dragFraction = nil
                onSeek(presentation.duration * fraction)
            }
    }

    private func clampedFraction(_ x: CGFloat, width: CGFloat) -> Double {
        min(max(Double(x / max(1, width)), 0), 1)
    }

    private func refreshAnchor() {
        anchor = MediaPlaybackAnchor(presentation: presentation, now: Date())
    }

    private func popCursorIfNeeded() {
        guard isHovering else { return }
        isHovering = false
        NSCursor.pop()
    }
}
