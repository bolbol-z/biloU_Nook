#if DEBUG
import AppKit
import Foundation
import QuartzCore
import os

enum MotionBench {
    static func run() {
        let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let refresh = NSScreen.main?.maximumFramesPerSecond ?? 60
        var openTo95: [CFTimeInterval] = []
        var closeTo95: [CFTimeInterval] = []

        let cycles = 20
        var cycle = 0
        func next() {
            if cycle >= cycles {
                writeReport(refresh: Int(refresh), openTo95: openTo95, closeTo95: closeTo95)
                exit(0)
            }
            cycle += 1
            // open
            let tEnter = CACurrentMediaTime()
            NotchState.shared.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let tOpenDone = CACurrentMediaTime()
                openTo95.append((tOpenDone - tEnter) * 1000)
                // close
                MouseMonitor.shared.onLeaveOpenArea?()
                let tExit = CACurrentMediaTime()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotchState.shared.requestClose(reason: .mouseLeft)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let tCloseDone = CACurrentMediaTime()
                        closeTo95.append((tCloseDone - tExit) * 1000)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            next()
                        }
                    }
                }
            }
        }
        next()
    }

    static func writeReport(refresh: Int, openTo95: [CFTimeInterval], closeTo95: [CFTimeInterval]) {
        func median(_ arr: [Double]) -> Double {
            let sorted = arr.sorted()
            guard !sorted.isEmpty else { return 0 }
            if sorted.count % 2 == 1 { return sorted[sorted.count/2] }
            return (sorted[sorted.count/2 - 1] + sorted[sorted.count/2]) / 2
        }
        func p95(_ arr: [Double]) -> Double {
            let sorted = arr.sorted()
            guard !sorted.isEmpty else { return 0 }
            let idx = Int(Double(sorted.count - 1) * 0.95)
            return sorted[idx]
        }
        var md = "# Motion bench\n\n"
        md += "Display refresh rate: \(refresh) Hz\n\n"
        md += "| Metric | Median (ms) | p95 (ms) |\n| --- | --- | --- |\n"
        md += "| openStart→95% | \(String(format: "%.1f", median(openTo95))) | \(String(format: "%.1f", p95(openTo95))) |\n"
        md += "| closeStart→95% | \(String(format: "%.1f", median(closeTo95))) | \(String(format: "%.1f", p95(closeTo95))) |\n"
        let path = "docs/motion-bench-before.md"
        try? md.write(toFile: path, atomically: true, encoding: .utf8)
        print(md)
    }
}
#endif
