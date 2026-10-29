import AppKit

enum LiveActivityLayout {
    static let horizontalWing: CGFloat = 36
    static let minimumContentWidth: CGFloat = 120

    static func hardwareNotchWidth(auxLeft: NSRect?, auxRight: NSRect?) -> CGFloat? {
        guard let auxLeft, let auxRight else { return nil }
        let width = auxRight.minX - auxLeft.maxX
        return width > 0 ? width : nil
    }

    static func targetWidth(
        baseWidth: CGFloat,
        notchWidth: CGFloat,
        isLiveActivityActive: Bool
    ) -> CGFloat {
        guard isLiveActivityActive else { return baseWidth }
        return max(baseWidth, notchWidth + horizontalWing * 2)
    }

    static func physicalNotchWidth(
        auxLeft: NSRect?,
        auxRight: NSRect?,
        safeAreaTop: CGFloat,
        closedWidth: CGFloat
    ) -> CGFloat? {
        if let width = hardwareNotchWidth(auxLeft: auxLeft, auxRight: auxRight) {
            return width
        }
        if safeAreaTop > 0 { return closedWidth }
        return nil
    }

    static func closedMetrics(
        base: NotchMetrics,
        physicalNotchWidth: CGFloat?,
        isLiveActivityActive: Bool
    ) -> NotchMetrics {
        let target = targetWidth(
            baseWidth: base.w,
            notchWidth: physicalNotchWidth ?? base.w,
            isLiveActivityActive: isLiveActivityActive
        )
        return NotchMetrics(w: target, h: base.h, t: base.t, b: base.b)
    }
}
