import SwiftUI

private struct MarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let overflow = max(0, textWidth - geometry.size.width)
            let shouldMarquee = !reduceMotion && overflow > 1

            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeometry in
                        Color.clear.preference(key: MarqueeWidthKey.self, value: textGeometry.size.width)
                    }
                )
                .offset(x: shouldMarquee && isAnimating ? -overflow : 0)
                .frame(width: geometry.size.width, alignment: .leading)
                .clipped()
                .mask(edgeFade(active: shouldMarquee))
                .onPreferenceChange(MarqueeWidthKey.self) { textWidth = $0 }
                .onChange(of: overflow) { _, newValue in
                    restart(overflow: newValue)
                }
                .onChange(of: reduceMotion) { _, _ in
                    restart(overflow: overflow)
                }
                .onAppear {
                    restart(overflow: overflow)
                }
                .onDisappear {
                    isAnimating = false
                }
        }
        .frame(height: height)
    }

    private func edgeFade(active: Bool) -> LinearGradient {
        LinearGradient(
            stops: active
                ? [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.045),
                    .init(color: .black, location: 0.955),
                    .init(color: .clear, location: 1),
                ]
                : [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 1),
                ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func restart(overflow: CGFloat) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isAnimating = false
        }
        guard overflow > 1, !reduceMotion else { return }
        let duration = min(8, max(1.8, Double(overflow) / 30))
        DispatchQueue.main.async {
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
