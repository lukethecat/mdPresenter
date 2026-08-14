import AppKit

// MARK: - Color utilities

public extension NSColor {
    /// Create a color from a hex string like "#RRGGBB" or "RRGGBB".
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    /// Perceived luminance in 0...1 (sRGB weights).
    var luminance: CGFloat {
        guard let c = usingColorSpace(.sRGB) else { return 0.5 }
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }

    var isDark: Bool { luminance < 0.45 }

    /// A readable text color on top of this color.
    var contrastingText: NSColor { isDark ? NSColor.white : NSColor.black }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func withAlpha(_ a: CGFloat) -> NSColor {
        guard let c = usingColorSpace(.sRGB) else { return self }
        return NSColor(srgbRed: c.redComponent, green: c.greenComponent, blue: c.blueComponent, alpha: a)
    }

    /// Mix two colors in device RGB space, t in 0...1.
    func mixed(with other: NSColor, t: CGFloat) -> NSColor {
        let tt = max(0, min(1, t))
        guard let a = usingColorSpace(.sRGB), let b = other.usingColorSpace(.sRGB) else { return self }
        return NSColor(
            srgbRed: a.redComponent + (b.redComponent - a.redComponent) * tt,
            green: a.greenComponent + (b.greenComponent - a.greenComponent) * tt,
            blue: a.blueComponent + (b.blueComponent - a.blueComponent) * tt,
            alpha: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * tt
        )
    }

    /// Interpolate through HSB (used for the blue→purple→red→orange→gold shift).
    func interpolated(to other: NSColor, t: CGFloat) -> NSColor {
        let tt = max(0, min(1, t))
        let (h1, s1, b1) = hsb
        let (h2, s2, b2) = other.hsb
        var dh = (h2 - h1).truncatingRemainder(dividingBy: 1)
        if dh > 0.5 { dh -= 1 }
        if dh < -0.5 { dh += 1 }
        let h = (h1 + dh * tt).truncatingRemainder(dividingBy: 1)
        return NSColor(
            hue: h < 0 ? h + 1 : h,
            saturation: s1 + (s2 - s1) * tt,
            brightness: b1 + (b2 - b1) * tt,
            alpha: 1
        )
    }

    var hsb: (h: CGFloat, s: CGFloat, b: CGFloat) {
        guard let c = usingColorSpace(.deviceRGB) else { return (0, 0, 0) }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }
}
