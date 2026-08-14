import AppKit

// MARK: - Progress color engine
//
// iA Presenter's signature "Color Shift", tuned to traditional Chinese
// pigments. The cursor and slide titles gradually travel from indigo to
// gold as you move through a presentation:
//   靛青 → cold start         (冷启动)
//   黛紫 → warming up         (预热)
//   朱砂 → things get hot     (高潮)
//   琥珀 → the sweet end      (收尾)
//   鎏金 → the afterglow      (余韵)

public struct ProgressColorEngine {

    public static let stops: [(NSColor, String)] = [
        (NSColor(hex: 0x1F6FB2), "靛青"),
        (NSColor(hex: 0x7B4FA6), "黛紫"),
        (NSColor(hex: 0xC3272B), "朱砂"),
        (NSColor(hex: 0xC96A2F), "琥珀"),
        (NSColor(hex: 0xC9A063), "鎏金"),
    ]

    /// Color at a given deck progress (0...1), interpolated through HSB.
    public static func color(at progress: Double) -> NSColor {
        let p = max(0, min(1, progress))
        let span = 1.0 / Double(stops.count - 1)
        let segment = min(Int(p / span), stops.count - 2)
        let local = (p - Double(segment) * span) / span
        return stops[segment].0.interpolated(to: stops[segment + 1].0, t: CGFloat(local))
    }

    /// Pigment name for the current progress (靛青/黛紫/朱砂/琥珀/鎏金).
    public static func stageName(at progress: Double) -> String {
        let p = max(0, min(1, progress))
        let span = 1.0 / Double(stops.count - 1)
        let segment = min(Int(p / span), stops.count - 1)
        return stops[segment].1
    }
}
