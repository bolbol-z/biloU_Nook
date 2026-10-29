import SwiftUI

struct EqualizerView: View {
    let isPlaying: Bool
    let height: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let phase = Double(index) * 1.7
                    let wave = (sin(time * 3.4 + phase) + 1) / 2
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: 2.5, height: max(2, height * (0.28 + 0.72 * wave)))
                }
            }
            .frame(width: 22, height: height, alignment: .bottom)
        }
        .frame(width: 22, height: height)
    }
}
