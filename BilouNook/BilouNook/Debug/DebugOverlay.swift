#if DEBUG
import SwiftUI
import AppKit

#if DEBUG
struct DebugOverlay: View {
    @State private var info: String = ""
    @StateObject private var settings = SettingsStore.shared
    @State private var nowPlaying = NowPlayingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
            HStack {
                Stepper(value: $settings.fineTuneWidth, in: -20...20) {
                    Text("W: \(Int(settings.fineTuneWidth))")
                }
                Stepper(value: $settings.fineTuneHeight, in: -20...20) {
                    Text("H: \(Int(settings.fineTuneHeight))")
                }
            }
            Divider()
            nowPlayingContent
        }
        .padding(6)
        .background(Color.black.opacity(0.82))
        .onAppear {
            updateInfo()
        }
        .onChange(of: settings.fineTuneWidth) { _, _ in updateInfo() }
        .onChange(of: settings.fineTuneHeight) { _, _ in updateInfo() }
        .onChange(of: settings.topFlareRadius) { _, _ in updateInfo() }
        .onChange(of: settings.bottomRadius) { _, _ in updateInfo() }
    }

    private func updateInfo() {
        let screen = ScreenResolver.shared.targetScreen()
        let geometry = NotchGeometry.live(for: screen, settings: settings)
        let closed = geometry.closedMetrics(isLiveActivityActive: false)
        info = """
        Screen: \(screen.localizedName)
        Notch: \(Int(geometry.notchRect.width))x\(Int(geometry.notchRect.height))
        Closed: \(String(format: "%.1f", closed.w))x\(String(format: "%.1f", closed.h))
        Top flare: \(String(format: "%.2f", geometry.topFlareRadius))
        Bottom: \(String(format: "%.2f", geometry.bottomRadius))
        Overlap: \(String(format: "%.2f", NotchGeometry.overlap))
        Scale: \(screen.backingScaleFactor)
        Insets: \(screen.safeAreaInsets.top)
        """
    }

    @ViewBuilder
    private var nowPlayingContent: some View {
        Text("Now Playing [\(nowPlaying.providerName)]")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.green)

        if let snapshot = nowPlaying.snapshot {
            HStack(alignment: .top, spacing: 8) {
                artworkView(snapshot.artwork)
                VStack(alignment: .leading, spacing: 2) {
                    text(snapshot.title, size: 11, weight: .semibold)
                    text(snapshot.artist, size: 10)
                    text(snapshot.album, size: 9)
                    text("\(format(snapshot.elapsed)) / \(format(snapshot.duration))", size: 9)
                    Text(snapshot.isPlaying ? "PLAYING" : "PAUSED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(snapshot.isPlaying ? .green : .orange)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: snapshot.progress)
                .tint(.green)
        } else {
            Text("No player")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private func artworkView(_ data: Data?) -> some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipped()
                .cornerRadius(4)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Text("No art")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.gray)
                )
        }
    }

    private func text(_ value: String, size: CGFloat, weight: Font.Weight = .regular) -> some View {
        Text(value.isEmpty ? "—" : value)
            .font(.system(size: size, weight: weight))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

@Observable
final class NotchCalibrationState {
    static let shared = NotchCalibrationState()

    var isVisible = false
    private var keyMonitor: Any?

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else {
            installKeyMonitor()
            return
        }
        isVisible = visible
        if visible {
            installKeyMonitor()
            printValues(label: "show")
        } else {
            printValues(label: "final")
        }
    }

    func toggle() {
        setVisible(!isVisible)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let option = event.modifierFlags.contains(.option)
        let step: CGFloat = 0.5
        switch event.keyCode {
        case 126:
            if option {
                adjustHeight(by: 1)
            } else {
                adjustTopFlare(by: step)
            }
        case 125:
            if option {
                adjustHeight(by: -1)
            } else {
                adjustTopFlare(by: -step)
            }
        case 123:
            if option {
                adjustWidth(by: -1)
            } else {
                adjustBottomRadius(by: -step)
            }
        case 124:
            if option {
                adjustWidth(by: 1)
            } else {
                adjustBottomRadius(by: step)
            }
        default:
            return false
        }
        printValues(label: "nudge")
        return true
    }

    private func adjustTopFlare(by delta: CGFloat) {
        let settings = SettingsStore.shared
        let geometry = NotchGeometry.live(settings: settings)
        settings.topFlareRadius = Double(max(0, geometry.topFlareRadius + delta))
    }

    private func adjustBottomRadius(by delta: CGFloat) {
        let settings = SettingsStore.shared
        let geometry = NotchGeometry.live(settings: settings)
        settings.bottomRadius = Double(max(0, geometry.bottomRadius + delta))
    }

    private func adjustWidth(by delta: CGFloat) {
        let settings = SettingsStore.shared
        let geometry = NotchGeometry.live(settings: settings)
        settings.fineTuneWidth = Double(max(-geometry.notchRect.width + 2, geometry.widthDelta + delta))
    }

    private func adjustHeight(by delta: CGFloat) {
        let settings = SettingsStore.shared
        let geometry = NotchGeometry.live(settings: settings)
        settings.fineTuneHeight = Double(max(-geometry.notchRect.height + 2, geometry.heightDelta + delta))
    }

    func printValues(label: String) {
        let geometry = NotchGeometry.live()
        let closed = geometry.closedMetrics(isLiveActivityActive: false)
        let notch = geometry.notchRect
        print(
            String(
                format: "NOTCH_CALIBRATION[%@] notch=%.3fx%.3f topFlareRadius=%.3f bottomRadius=%.3f widthDelta=%.3f heightDelta=%.3f overlap=%.3f closed=%.3fx%.3f",
                label,
                notch.width,
                notch.height,
                geometry.topFlareRadius,
                geometry.bottomRadius,
                geometry.widthDelta,
                geometry.heightDelta,
                NotchGeometry.overlap,
                closed.w,
                closed.h
            )
        )
        fflush(stdout)
    }
}

struct NotchCalibrationOverlay: View {
    let geometry: NotchGeometry
    let panel: NSPanel

    var body: some View {
        GeometryReader { proxy in
            let topLine = Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
            }
            ZStack(alignment: .topLeading) {
                topLine.stroke(Color.cyan, lineWidth: 1)

                if let hardware = geometry.hardwareNotchRect {
                    let rect = rootRect(hardware)
                    Rectangle()
                        .path(in: rect)
                        .stroke(Color(red: 1, green: 0, blue: 1), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "notch %.1fx%.1f", geometry.notchRect.width, geometry.notchRect.height))
                    Text(String(format: "top flare %.2f  bottom %.2f", geometry.topFlareRadius, geometry.bottomRadius))
                    Text(String(format: "width %+.1f  height %+.1f  overlap %.1f", geometry.widthDelta, geometry.heightDelta, NotchGeometry.overlap))
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white)
                .padding(4)
                .background(Color.black.opacity(0.75))
                .offset(x: 8, y: 40)
            }
        }
        .allowsHitTesting(false)
    }

    private func rootRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - panel.frame.minX,
            y: panel.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

class DebugOverlayWindow {
    static let shared = DebugOverlayWindow()
    private(set) var window: NSWindow?

    func toggle() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            if window.isVisible {
                window.orderOut(nil)
                NotchCalibrationState.shared.setVisible(false)
            } else {
                window.makeKeyAndOrderFront(nil)
                NotchCalibrationState.shared.setVisible(true)
            }
            return
        }
        NotchCalibrationState.shared.setVisible(true)
        let screen = ScreenResolver.shared.targetScreen()
        let w = NSWindow(
            contentRect: NSRect(x: screen.frame.midX - 180, y: screen.frame.maxY - 280, width: 360, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isReleasedWhenClosed = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.contentView = NSHostingView(rootView: DebugOverlay())
        window = w
        w.makeKeyAndOrderFront(nil)
    }
}
#endif

#endif
