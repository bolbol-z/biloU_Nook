import AppKit

struct NotchRect: Equatable {
    let width: CGFloat
    let height: CGFloat
}

struct NotchGeometry: Equatable {
    static let overlap: CGFloat = 0.5
    static let virtualWidth: CGFloat = 200
    static let virtualHeight: CGFloat = 32
    static let forbiddenZoneExpansion: CGFloat = 6

    let screenFrame: CGRect
    let backingScaleFactor: CGFloat
    let hardwareNotchRect: CGRect?
    let safeAreaTop: CGFloat
    let widthDelta: CGFloat
    let heightDelta: CGFloat
    let topFlareRadiusOverride: CGFloat
    let bottomRadiusOverride: CGFloat

    init(
        screenFrame: CGRect,
        backingScaleFactor: CGFloat,
        auxLeft: CGRect?,
        auxRight: CGRect?,
        safeAreaTop: CGFloat,
        widthDelta: CGFloat = 0,
        heightDelta: CGFloat = 0,
        topFlareRadiusOverride: CGFloat = 0,
        bottomRadiusOverride: CGFloat = 0
    ) {
        self.screenFrame = screenFrame
        self.backingScaleFactor = backingScaleFactor
        self.hardwareNotchRect = Self.resolveHardwareNotchRect(
            screenFrame: screenFrame,
            auxLeft: auxLeft,
            auxRight: auxRight,
            safeAreaTop: safeAreaTop
        )
        self.safeAreaTop = safeAreaTop
        self.widthDelta = widthDelta
        self.heightDelta = heightDelta
        self.topFlareRadiusOverride = topFlareRadiusOverride
        self.bottomRadiusOverride = bottomRadiusOverride
    }

    static func live(
        for screen: NSScreen = ScreenResolver.shared.targetScreen(),
        settings: SettingsStore = .shared
    ) -> NotchGeometry {
        NotchGeometry(
            screenFrame: screen.frame,
            backingScaleFactor: screen.backingScaleFactor,
            auxLeft: screen.auxiliaryTopLeftArea,
            auxRight: screen.auxiliaryTopRightArea,
            safeAreaTop: screen.safeAreaInsets.top,
            widthDelta: CGFloat(settings.fineTuneWidth),
            heightDelta: CGFloat(settings.fineTuneHeight),
            topFlareRadiusOverride: CGFloat(settings.topFlareRadius),
            bottomRadiusOverride: CGFloat(settings.bottomRadius)
        )
    }

    var isPhysicalNotch: Bool {
        hardwareNotchRect != nil
    }

    var notchRect: CGRect {
        hardwareNotchRect ?? virtualNotchRect
    }

    var virtualNotchRect: CGRect {
        let height = max(Self.virtualHeight, safeAreaTop)
        return CGRect(
            x: screenFrame.midX - Self.virtualWidth / 2,
            y: screenFrame.maxY - height,
            width: Self.virtualWidth,
            height: height
        )
    }

    var topFlareRadius: CGFloat {
        let raw = topFlareRadiusOverride > 0
            ? topFlareRadiusOverride
            : min(max(notchRect.height * 0.1875, 3), 8)
        return min(raw, max(0, min(shapeWidth, shapeHeight) / 2))
    }

    var bottomRadius: CGFloat {
        let raw = bottomRadiusOverride > 0
            ? bottomRadiusOverride
            : min(max(notchRect.height * 0.4375, 6), 16)
        return min(raw, max(0, min(shapeWidth, shapeHeight) / 2))
    }

    func closedMetrics(isLiveActivityActive: Bool) -> NotchMetrics {
        let baseWidth = max(shapeWidth, 2)
        let baseHeight = max(shapeHeight, 2)
        let overlappedWidth = baseWidth + Self.overlap * 2
        let targetWidth = LiveActivityLayout.targetWidth(
            baseWidth: overlappedWidth,
            notchWidth: baseWidth,
            isLiveActivityActive: isLiveActivityActive
        )
        let width = Self.pixelAlignedWidth(
            targetWidth,
            scale: backingScaleFactor
        )

        return NotchMetrics(
            w: width,
            h: Self.pixelCeil(baseHeight + Self.overlap, scale: backingScaleFactor),
            t: topFlareRadius,
            b: bottomRadius
        )
    }

    func openMetrics(for contentSize: CGSize) -> NotchMetrics {
        let width = Self.pixelAlignedWidth(
            max(contentSize.width, 2),
            scale: backingScaleFactor
        )
        let height = Self.pixelCeil(
            max(contentSize.height, 2),
            scale: backingScaleFactor
        )
        let limit = max(0, min(width, height) / 2)
        return NotchMetrics(
            w: width,
            h: height,
            t: min(topFlareRadius, limit),
            b: min(bottomRadius, limit)
        )
    }

    static func pixelCeil(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return value }
        return ceil(value * scale) / scale
    }

    static func pixelAlignedWidth(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return value }
        let pixels = (value * scale).rounded()
        let evenPixels = pixels.truncatingRemainder(dividingBy: 2) == 0
            ? pixels
            : pixels + 1
        return evenPixels / scale
    }

    private var shapeWidth: CGFloat {
        max(notchRect.width + widthDelta, 2)
    }

    private var shapeHeight: CGFloat {
        max(notchRect.height + heightDelta, 2)
    }

    private static func resolveHardwareNotchRect(
        screenFrame: CGRect,
        auxLeft: CGRect?,
        auxRight: CGRect?,
        safeAreaTop: CGFloat
    ) -> CGRect? {
        guard safeAreaTop > 0, let auxLeft, let auxRight else { return nil }
        guard let width = LiveActivityLayout.hardwareNotchWidth(
            auxLeft: auxLeft,
            auxRight: auxRight
        ) else {
            return nil
        }
        return CGRect(
            x: auxLeft.maxX,
            y: screenFrame.maxY - safeAreaTop,
            width: width,
            height: safeAreaTop
        )
    }

    var forbiddenZone: CGRect {
        let base = notchRect
        return CGRect(
            x: base.minX - Self.forbiddenZoneExpansion,
            y: base.minY,
            width: base.width + Self.forbiddenZoneExpansion * 2,
            height: base.height
        )
    }

    func forbiddenZone(inShapeSpace shapeWidth: CGFloat? = nil) -> CGRect {
        let base = notchRect
        let screen = screenFrame
        let shapeW = shapeWidth ?? base.width
        let originX = screen.midX - shapeW / 2
        let originY = screen.maxY // shape origin in screen coords relative to panel positioning varies; but easier to give relative to shape centered at screen.midX top
        // Shape coordinates: relative to the shape rect positioned centered at top of screen in panel space
        let fx = (base.minX - Self.forbiddenZoneExpansion) - (screen.midX - shapeW / 2)
        let fy = base.minY - (screen.maxY - base.height) // approximate; better use y from 0 in shape coords relative to shape top
        // Simpler: in shape coordinates with origin at top-left of shape, y from 0 to height
        let shapeOriginX = screen.midX - shapeW / 2
        let shapeOriginY = screen.maxY - base.height // top of shape area
        return CGRect(
            x: base.minX - Self.forbiddenZoneExpansion - shapeOriginX,
            y: 0,
            width: base.width + Self.forbiddenZoneExpansion * 2,
            height: base.height
        )
    }

    var topBandFlanks: (left: CGRect, right: CGRect) {
        let notch = notchRect
        let forbidden = forbiddenZone
        let leftFlank = CGRect(
            x: notch.minX,
            y: notch.minY,
            width: max(0, forbidden.minX - notch.minX),
            height: notch.height
        )
        let rightFlank = CGRect(
            x: forbidden.maxX,
            y: notch.minY,
            width: max(0, notch.maxX - forbidden.maxX),
            height: notch.height
        )
        return (left: leftFlank, right: rightFlank)
    }

    func topBandFlanks(inShapeSpace shapeWidth: CGFloat) -> (left: CGRect, right: CGRect) {
        let screen = screenFrame
        let shapeOriginX = screen.midX - shapeWidth / 2
        let notch = notchRect
        let forbidden = forbiddenZone
        let leftWidth = max(0, forbidden.minX - notch.minX)
        let rightWidth = max(0, notch.maxX - forbidden.maxX)
        let leftFlank = CGRect(
            x: notch.minX - shapeOriginX,
            y: 0,
            width: leftWidth,
            height: notch.height
        )
        let rightFlank = CGRect(
            x: forbidden.maxX - shapeOriginX,
            y: 0,
            width: rightWidth,
            height: notch.height
        )
        return (left: leftFlank, right: rightFlank)
    }

    var contentTop: CGFloat {
        notchRect.height + 6
    }
}
