import AppKit

// MARK: - Progress color engine
//
// iA Presenter's signature "Color Shift", tuned to the post-WWDC25 Apple
// system palette (HIG 2025-06-09 refresh). The cursor and slide titles
// gradually travel from systemBlue to gold as you move through a talk:
//   Blue   → cold start         (冷启动)
//   Indigo → warming up         (预热)
//   Red    → things get hot     (高潮)
//   Orange → the sweet end      (收尾)
//   Gold   → the afterglow      (余韵)

public struct ProgressColorEngine {

    public static let stops: [(NSColor, String)] = [
        (NSColor(hex: 0x0088FF), "Blue"),
        (NSColor(hex: 0x6155F5), "Indigo"),
        (NSColor(hex: 0xFF383C), "Red"),
        (NSColor(hex: 0xFF8D28), "Orange"),
        (NSColor(hex: 0xFFCC00), "Gold"),
    ]

    /// Color at a given deck progress (0...1), interpolated through HSB.
    public static func color(at progress: Double) -> NSColor {
        let p = max(0, min(1, progress))
        let span = 1.0 / Double(stops.count - 1)
        let segment = min(Int(p / span), stops.count - 2)
        let local = (p - Double(segment) * span) / span
        return stops[segment].0.interpolated(to: stops[segment + 1].0, t: CGFloat(local))
    }

    /// Stage name for the current progress (Blue/Indigo/Red/Orange/Gold).
    public static func stageName(at progress: Double) -> String {
        let p = max(0, min(1, progress))
        let span = 1.0 / Double(stops.count - 1)
        let segment = min(Int(p / span), stops.count - 1)
        return stops[segment].1
    }
}
