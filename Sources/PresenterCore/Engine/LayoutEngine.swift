import AppKit
import Foundation

// MARK: - Layout engine
//
// "Presenter automatically analyzes your slide content and creates an
// optimal layout that looks great on any display." We pick the layout in
// ContentResolver; this engine handles auto-scaling type and media so that
// everything fits any canvas size — phone, PC or projector.

public struct LayoutEngine {

    /// Binary-search the largest font size that fits `text` inside
    /// (width × height) for the given family/weight, honoring line wraps.
    public static func fitFontSize(
        text: String,
        family: String,
        weight: NSFont.Weight,
        maxSize: CGFloat,
        minSize: CGFloat,
        in size: CGSize,
        lineSpacing: CGFloat = 1.08
    ) -> CGFloat {
        guard !text.isEmpty, size.width > 20, size.height > 20 else { return minSize }
        var lo = minSize
        var hi = maxSize
        var best = minSize
        for _ in 0..<12 {
            let mid = (lo + hi) / 2
            if fits(text: text, family: family, weight: weight, fontSize: mid, in: size, lineSpacing: lineSpacing) {
                best = mid
                lo = mid
            } else {
                hi = mid
            }
            if hi - lo < 0.5 { break }
        }
        return best
    }

    static func fits(
        text: String,
        family: String,
        weight: NSFont.Weight,
        fontSize: CGFloat,
        in size: CGSize,
        lineSpacing: CGFloat
    ) -> Bool {
        let font = Typography.font(family: family, size: fontSize, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = fontSize * (lineSpacing - 1)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
        ]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        return bounds.width <= size.width + 0.5 && bounds.height <= size.height + 0.5
    }

    /// Estimate a headline size from character count — quick approximation
    /// used before the precise fit runs.
    public static func roughHeadlineSize(text: String, canvasWidth: CGFloat) -> CGFloat {
        let count = text.count
        let cjk = text.filter { $0.unicodeScalars.first.map { $0.value > 0x2E80 } ?? false }.count
        let units = cjk * 2 + (count - cjk)
        let perLine = max(4, Int(canvasWidth / 24))
        let lines = max(1, units / perLine + 1)
        return clamp(canvasWidth / 7.0, 28, 120) / CGFloat(min(lines, 4))
    }

    /// Media fitting: scale an image down to a box while keeping aspect.
    public static func fittedMediaSize(mediaSize: CGSize, in box: CGSize) -> CGSize {
        guard mediaSize.width > 0, mediaSize.height > 0 else { return box }
        let scale = min(box.width / mediaSize.width, box.height / mediaSize.height, 1.0)
        return CGSize(width: mediaSize.width * scale, height: mediaSize.height * scale)
    }
}

func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, v)) }
