import Foundation

// MARK: - TurboStart
//
// iA Presenter's TurboStart converts pasted or imported plain text into
// slides instantly. Without any separators we apply heuristics:
//   * every paragraph becomes a slide,
//   * a short leading line becomes the slide's headline,
//   * longer paragraphs are split so the first sentence becomes the headline
//     and the remainder becomes speaker notes.

public struct TurboStart {

    public enum Result {
        case untouched(String)      // nothing to do (already separated)
        case converted(String)      // text rewritten as slides
    }

    /// Decide whether the text already contains slide separators.
    public static func hasSeparators(_ text: String) -> Bool {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.range(of: "\n[ \\t]*---+[ \\t]*\n", options: .regularExpression) != nil { return true }
        if normalized.contains("\n\n\n") { return true }
        return false
    }

    /// Convert plain prose into slide markdown.
    public static func convert(_ text: String) -> Result {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if hasSeparators(normalized) { return .untouched(normalized) }

        let paragraphs = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard paragraphs.count >= 2 else { return .untouched(normalized) }

        var slides: [String] = []
        for para in paragraphs {
            let lines = para.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }

            var body = lines
            var headline: String? = nil

            // Short paragraph → the whole thing is a headline.
            if lines.count == 1 && lines[0].count <= 60 {
                headline = lines[0]
                body = []
            } else if let first = body.first, first.count <= 80 {
                // Long paragraph → leading short line becomes the headline.
                headline = first
                body.removeFirst()
            } else {
                // Long first line → carve out the first sentence as headline.
                let firstSentence = firstSentence(of: body[0])
                if !firstSentence.isEmpty && firstSentence.count <= 100 {
                    headline = firstSentence
                    let remainder = String(body[0].dropFirst(firstSentence.count))
                        .trimmingCharacters(in: .whitespaces)
                    if remainder.isEmpty {
                        body.removeFirst()
                    } else {
                        body[0] = remainder
                    }
                }
            }

            var slide = ""
            if let h = headline {
                slide += "# \(h)\n"
            } else {
                slide += "# 幻灯片 \(slides.count + 1)\n"
            }
            for b in body {
                slide += "\n\(b)\n"
            }
            slides.append(slide.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .converted(slides.joined(separator: "\n\n\n"))
    }

    /// First sentence of a string — respects Latin and CJK punctuation.
    static func firstSentence(of text: String) -> String {
        let terminators: [Character] = [".", "!", "?", "。", "！", "？"]
        var best: String.Index? = nil
        for t in terminators {
            if let idx = text.firstIndex(of: t) {
                if best == nil || idx < best! { best = idx }
            }
        }
        guard let end = best else { return text }
        return String(text[...end]).trimmingCharacters(in: .whitespaces)
    }
}
