import SwiftUI

struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var topCornerRadius: CGFloat = 6
    var bottomCornerRadius: CGFloat = 14
    
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(AnimatablePair(width, height), AnimatablePair(topCornerRadius, bottomCornerRadius))
        }
        set {
            width = newValue.first.first
            height = newValue.first.second
            topCornerRadius = newValue.second.first
            bottomCornerRadius = newValue.second.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let metrics = NotchShapeMetrics.clamped(
            NotchMetrics(w: width, h: height, t: topCornerRadius, b: bottomCornerRadius)
        )
        let w = metrics.w
        let h = metrics.h
        let t = metrics.t
        let b = metrics.b
        
        var path = Path()
        let centerX = rect.midX
        let originX = centerX - w / 2
        let originY = rect.minY
        
        path.move(to: CGPoint(x: originX, y: originY))
        path.addQuadCurve(to: CGPoint(x: originX + t, y: originY + t), control: CGPoint(x: originX + t, y: originY))
        path.addLine(to: CGPoint(x: originX + t, y: originY + h - b))
        path.addQuadCurve(to: CGPoint(x: originX + t + b, y: originY + h), control: CGPoint(x: originX + t, y: originY + h))
        path.addLine(to: CGPoint(x: originX + w - t - b, y: originY + h))
        path.addQuadCurve(to: CGPoint(x: originX + w - t, y: originY + h - b), control: CGPoint(x: originX + w - t, y: originY + h))
        path.addLine(to: CGPoint(x: originX + w - t, y: originY + t))
        path.addQuadCurve(to: CGPoint(x: originX + w, y: originY), control: CGPoint(x: originX + w - t, y: originY))
        path.closeSubpath()
        return path
    }
}

struct NotchMetrics: Equatable {
    var w: CGFloat
    var h: CGFloat
    var t: CGFloat
    var b: CGFloat
}

enum NotchShapeMetrics {
    static func clamped(_ metrics: NotchMetrics) -> NotchMetrics {
        let w = max(0, metrics.w)
        let h = max(0, metrics.h)
        let limit = max(0, min(w, h) / 2)
        return NotchMetrics(
            w: w,
            h: h,
            t: min(max(0, metrics.t), limit),
            b: min(max(0, metrics.b), limit)
        )
    }
}

enum NotchMorph {
    static func metrics(
        from: NotchMetrics,
        to: NotchMetrics,
        progress: CGFloat
    ) -> NotchMetrics {
        let p = min(max(progress, 0), 1)
        func value(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
            start + (end - start) * p
        }
        return NotchMetrics(
            w: value(from.w, to.w),
            h: value(from.h, to.h),
            t: value(from.t, to.t),
            b: value(from.b, to.b)
        )
    }
}

enum NotchPresets {
    static func closed(notchW: CGFloat, notchH: CGFloat) -> NotchMetrics {
        return NotchMetrics(w: notchW, h: notchH, t: 6, b: 14)
    }
    static let open: NotchMetrics = NotchMetrics(w: 480, h: 150, t: 6, b: 14)
}
