import AppKit

enum NotchAttachment {
    static func hardwareNotchRect(
        screenFrame: CGRect,
        auxLeft: CGRect?,
        auxRight: CGRect?,
        safeAreaTop: CGFloat
    ) -> CGRect {
        NotchGeometry(
            screenFrame: screenFrame,
            backingScaleFactor: 1,
            auxLeft: auxLeft,
            auxRight: auxRight,
            safeAreaTop: safeAreaTop
        ).hardwareNotchRect ?? .zero
    }

    static func backingAlignedRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
        guard scale > 0 else { return rect }
        func aligned(_ value: CGFloat) -> CGFloat {
            (value * scale).rounded() / scale
        }
        let minX = aligned(rect.minX)
        let minY = aligned(rect.minY)
        let maxX = aligned(rect.maxX)
        let maxY = aligned(rect.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func panelFrame(
        screenFrame: CGRect,
        panelSize: CGSize,
        scale: CGFloat
    ) -> CGRect {
        let desired = CGRect(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
        return backingAlignedRect(desired, scale: scale)
    }
}
