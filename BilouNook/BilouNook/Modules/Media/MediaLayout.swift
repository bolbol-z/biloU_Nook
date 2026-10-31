import AppKit
import CoreGraphics
import SwiftUI

struct MediaLayoutMetrics: Equatable {
    let sideClearance: CGFloat
    let topClearanceGap: CGFloat
    let bottomClearance: CGFloat
    let artworkSize: CGFloat
    let artworkCornerRadius: CGFloat
    let columnSpacing: CGFloat
    let sourceBadgeSize: CGFloat

    static let standard = MediaLayoutMetrics(
        sideClearance: 18,
        topClearanceGap: 4,
        bottomClearance: 14,
        artworkSize: 76,
        artworkCornerRadius: 12,
        columnSpacing: 14,
        sourceBadgeSize: 16
    )
}

struct MediaShapeGeometry: Equatable {
    let width: CGFloat
    let height: CGFloat
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat

    init(
        width: CGFloat,
        height: CGFloat,
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat
    ) {
        self.width = width
        self.height = height
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    init(_ metrics: NotchMetrics) {
        self.init(
            width: metrics.w,
            height: metrics.h,
            topCornerRadius: metrics.t,
            bottomCornerRadius: metrics.b
        )
    }

    var clampedTopCornerRadius: CGFloat {
        min(max(0, topCornerRadius), min(width, height) / 2)
    }

    var clampedBottomCornerRadius: CGFloat {
        min(max(0, bottomCornerRadius), min(width, height) / 2)
    }
}

struct NotchContentSafeArea: Equatable {
    let shape: MediaShapeGeometry
    let topClearance: CGFloat
    let sideInset: CGFloat
    let bottomInset: CGFloat

    var contentRect: CGRect {
        CGRect(
            x: sideInset,
            y: topClearance,
            width: max(0, shape.width - sideInset * 2),
            height: max(0, shape.height - topClearance - bottomInset)
        )
    }

    var leftInset: CGFloat { contentRect.minX }
    var rightInset: CGFloat { max(0, shape.width - contentRect.maxX) }
    var contentHeight: CGFloat { contentRect.height }

    static func resolve(
        shape: MediaShapeGeometry,
        notchHeight: CGFloat,
        menuBarHeight: CGFloat
    ) -> NotchContentSafeArea {
        let contentTop = notchHeight + 6
        let topClearance = contentTop
        let bottomInset = min(
            MediaLayoutMetrics.standard.bottomClearance,
            max(0, shape.height)
        )
        let contentBottom = max(0, shape.height - bottomInset)
        let arcStart = max(0, shape.height - shape.clampedBottomCornerRadius)
        let arcDepth = max(0, contentBottom - arcStart)
        let arcFraction = shape.clampedBottomCornerRadius > 0
            ? min(max(arcDepth / shape.clampedBottomCornerRadius, 0), 1)
            : 0
        let arcInset = shape.clampedBottomCornerRadius * arcFraction * arcFraction
        var sideInset = min(
            max(0, shape.width) / 2,
            shape.clampedTopCornerRadius
                + MediaLayoutMetrics.standard.sideClearance
                + arcInset
        )
        // Ensure equal and at least 18pt, increased where bottom corner arc cuts in
        sideInset = max(sideInset, 18)
        // Keep equal on both sides (symmetric)
        sideInset = min(sideInset, max(0, shape.width) / 2)

        return NotchContentSafeArea(
            shape: shape,
            topClearance: topClearance,
            sideInset: sideInset,
            bottomInset: bottomInset
        )
    }

    func minimumDistance(from frame: CGRect) -> CGFloat {
        guard shape.width > 0, shape.height > 0 else { return 0 }

        var minimum = CGFloat.greatestFiniteMagnitude
        for point in Self.boundaryPoints(for: shape) {
            let dx = max(max(frame.minX - point.x, 0), point.x - frame.maxX)
            let dy = max(max(frame.minY - point.y, 0), point.y - frame.maxY)
            minimum = min(minimum, sqrt(dx * dx + dy * dy))
        }
        return minimum.isFinite ? minimum : 0
    }

    private static func boundaryPoints(for shape: MediaShapeGeometry) -> [CGPoint] {
        let w = shape.width
        let h = shape.height
        let t = shape.clampedTopCornerRadius
        let b = shape.clampedBottomCornerRadius
        guard w > 0, h > 0 else { return [] }

        var points: [CGPoint] = []
        points.append(CGPoint(x: 0, y: 0))
        appendQuadratic(
            from: CGPoint(x: 0, y: 0),
            control: CGPoint(x: t, y: 0),
            to: CGPoint(x: t, y: t),
            into: &points
        )
        points.append(CGPoint(x: t, y: max(t, h - b)))
        appendQuadratic(
            from: CGPoint(x: t, y: max(t, h - b)),
            control: CGPoint(x: t, y: h),
            to: CGPoint(x: min(w, t + b), y: h),
            into: &points
        )
        points.append(CGPoint(x: max(t + b, w - t - b), y: h))
        appendQuadratic(
            from: CGPoint(x: max(t + b, w - t - b), y: h),
            control: CGPoint(x: w - t, y: h),
            to: CGPoint(x: w - t, y: max(t, h - b)),
            into: &points
        )
        points.append(CGPoint(x: w - t, y: t))
        appendQuadratic(
            from: CGPoint(x: w - t, y: t),
            control: CGPoint(x: w, y: 0),
            to: CGPoint(x: w, y: 0),
            into: &points
        )
        points.append(CGPoint(x: 0, y: 0))
        return points
    }

    private static func appendQuadratic(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        into points: inout [CGPoint]
    ) {
        let steps = 32
        for index in 1...steps {
            let t = CGFloat(index) / CGFloat(steps)
            let inverse = 1 - t
            let x = inverse * inverse * start.x
                + 2 * inverse * t * control.x
                + t * t * end.x
            let y = inverse * inverse * start.y
                + 2 * inverse * t * control.y
                + t * t * end.y
            points.append(CGPoint(x: x, y: y))
        }
    }
}

enum MediaLayout {
    static let width: CGFloat = 420
    static let metrics = MediaLayoutMetrics.standard

    static let shellTabBarHeight: CGFloat = 0
    static let titleHeight: CGFloat = 19 // approx for 15pt
    static let titleToArtist: CGFloat = 2
    static let artistHeight: CGFloat = 16 // approx for 12pt
    static let artistToProgress: CGFloat = 10
    static let progressHitHeight: CGFloat = 20
    static let progressToTimes: CGFloat = 4
    static let timeRowHeight: CGFloat = 13 // 10.5pt
    static let timesToControls: CGFloat = 6
    static let controlsHeight: CGFloat = 38

    static let contentHeight: CGFloat = titleHeight
        + titleToArtist
        + artistHeight
        + artistToProgress
        + progressHitHeight
        + progressToTimes
        + timeRowHeight
        + timesToControls
        + controlsHeight

    static let trackHeight: CGFloat = 4
    static let expandedTrackHeight: CGFloat = 4
    static let controlHitSize: CGFloat = 38
    static let playSymbolSize: CGFloat = 16
    static let transportSymbolSize: CGFloat = 10
    static let ambientOpacity: Double = 0.14

    static func preferredHeight(notchHeight: CGFloat, menuBarHeight: CGFloat) -> CGFloat {
        notchHeight + 6
            + contentHeight
            + MediaLayoutMetrics.standard.bottomClearance
    }

    static func preferredSize(notchHeight: CGFloat, menuBarHeight: CGFloat) -> CGSize {
        CGSize(
            width: width,
            height: preferredHeight(notchHeight: notchHeight, menuBarHeight: menuBarHeight)
        )
    }

    static func livePreferredSize() -> CGSize {
        let screen = ScreenResolver.shared.targetScreen()
        return preferredSize(
            notchHeight: screen.safeAreaInsets.top,
            menuBarHeight: NSStatusBar.system.thickness
        )
    }

    static func liveSafeArea() -> NotchContentSafeArea {
        let screen = ScreenResolver.shared.targetScreen()
        let size = preferredSize(
            notchHeight: screen.safeAreaInsets.top,
            menuBarHeight: NSStatusBar.system.thickness
        )
        let metrics = NotchGeometry.live(for: screen).openMetrics(for: size)
        return NotchContentSafeArea.resolve(
            shape: MediaShapeGeometry(metrics),
            notchHeight: screen.safeAreaInsets.top,
            menuBarHeight: NSStatusBar.system.thickness
        )
    }

    #if DEBUG
    static let probeCoordinateSpace = "bilounook.media.layout"
    #endif
}

#if DEBUG
enum MediaLayoutProbe: String, CaseIterable {
    case artwork
    case textColumn
    case title
    case artist
    case progressTrack
    case timeRow
    case elapsedTime
    case remainingTime
    case controls
}

enum MediaTimeLabel: String, CaseIterable {
    case elapsed
    case remaining
}

struct MediaTimeLabelProbeKey: PreferenceKey {
    static var defaultValue: [MediaTimeLabel: [CGRect]] = [:]

    static func reduce(
        value: inout [MediaTimeLabel: [CGRect]],
        nextValue: () -> [MediaTimeLabel: [CGRect]]
    ) {
        for (label, frames) in nextValue() {
            value[label, default: []].append(contentsOf: frames)
        }
    }
}

struct MediaLayoutProbeKey: PreferenceKey {
    static var defaultValue: [MediaLayoutProbe: CGRect] = [:]

    static func reduce(
        value: inout [MediaLayoutProbe: CGRect],
        nextValue: () -> [MediaLayoutProbe: CGRect]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func mediaLayoutProbe(_ probe: MediaLayoutProbe) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: MediaLayoutProbeKey.self,
                    value: [probe: geometry.frame(in: .named(MediaLayout.probeCoordinateSpace))]
                )
            }
        }
    }

    func mediaTimeLabelProbe(_ label: MediaTimeLabel) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: MediaTimeLabelProbeKey.self,
                    value: [label: [geometry.frame(in: .named(MediaLayout.probeCoordinateSpace))]]
                )
            }
        }
    }
}
#endif
