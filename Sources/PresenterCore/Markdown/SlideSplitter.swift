import Foundation

// MARK: - Slide splitting
//
// iA Presenter creates a new slide when you either
//   1. type three dashes `---` on their own line, or
//   2. press Return three times (two empty lines).
// Deleting the separator merges the slides again.

public struct SlideSplitter {

    /// Split raw markdown text into slides.
    /// - Parameter text: the full document text (any line-ending style).
    /// - Returns: an array of `Slide` models (pure text only, no parsing yet).
    public static func split(_ text: String) -> [Slide] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let allLines = normalized.components(separatedBy: "\n")
        var slides: [Slide] = []
        var current: [String] = []
        var startLine = 0
        var lineIndex = 0
        var emptyRun = 0

        func flush() {
            // 只裁剪换行（分隔符留下的空行）。绝不能裁剪空白字符：
            // 首行是 Tab 缩进的可见文本时（空白文档第一句就按 Tab 的
            // 场景），whitespacesAndNewlines 会把前导 Tab 一起剥掉，
            // 导致上屏文本静默掉进演讲备注。
            let source = current.joined(separator: "\n")
                .trimmingCharacters(in: .newlines)
            if !source.isEmpty {
                slides.append(Slide(source: source, startLine: startLine, lineCount: current.count))
            }
            current = []
        }

        for line in allLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isRule = trimmed == "---" || trimmed == "***" || trimmed == "___"
                || (trimmed.count >= 3
                    && trimmed.allSatisfy { $0 == "-" }
                    && !trimmed.contains(" "))
            if isRule {
                flush()
                startLine = lineIndex + 1
                emptyRun = 0
            } else if trimmed.isEmpty {
                emptyRun += 1
                if emptyRun >= 2 {
                    // Two empty lines = three Returns = new slide.
                    flush()
                    startLine = lineIndex + 1
                    emptyRun = 0
                } else {
                    current.append(line)
                }
            } else {
                emptyRun = 0
                current.append(line)
            }
            lineIndex += 1
        }
        flush()
        return slides
    }

    /// Find the slide index containing a given character location (for the editor).
    public static func slideIndex(at characterIndex: Int, in slides: [Slide], text: NSString) -> Int? {
        guard !slides.isEmpty else { return 0 }
        var last: Int? = nil
        for (i, slide) in slides.enumerated() {
            let range = slide.characterRange(in: text)
            if characterIndex >= range.location && characterIndex < NSMaxRange(range) {
                return i
            }
            if characterIndex >= NSMaxRange(range) { last = i }
        }
        if characterIndex <= 0 { return 0 }
        return last
    }

    /// Character range of the first line of a slide, used to scroll to it.
    public static func firstLineRange(of slide: Slide, in text: NSString) -> NSRange {
        let range = slide.characterRange(in: text)
        let lines = slide.source.components(separatedBy: "\n")
        let length = lines.isEmpty ? 0 : (lines[0] as NSString).length
        return NSRange(location: range.location, length: min(length, range.length))
    }
}

public extension Slide {
    /// Character range of this slide inside the whole document.
    func characterRange(in text: NSString) -> NSRange {
        let lines = text.components(separatedBy: "\n") as [String]
        guard startLine < lines.count else { return NSRange(location: 0, length: 0) }
        var location = 0
        for i in 0..<min(startLine, lines.count) {
            location += (lines[i] as NSString).length + 1
        }
        var length = 0
        for i in startLine..<min(startLine + lineCount, lines.count) {
            length += (lines[i] as NSString).length + 1
        }
        return NSRange(location: location, length: max(0, length - 1))
    }
}
