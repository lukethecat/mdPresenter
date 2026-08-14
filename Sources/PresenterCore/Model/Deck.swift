import Foundation

// MARK: - Deck: the parsed presentation
//
// Text → SlideSplitter → MarkdownParser → ContentResolver.
// This is the pure, testable pipeline the whole app renders from.

public struct Deck: Equatable {
    public var slides: [Slide] = []
    public var contents: [SlideContent] = []

    public init(text: String) {
        slides = SlideSplitter.split(text).map { source in
            var s = source
            s.blocks = MarkdownParser.parseBlocks(source.source)
            return s
        }
        contents = ContentResolver.resolve(slides: slides)
    }

    public init() {}

    /// Render markdown for a single slide back to text (used for merge/split ops).
    public func markdownText() -> String {
        slides.map { $0.source }.joined(separator: "\n\n\n")
    }

    public func slide(at characterIndex: Int, in text: NSString) -> Int? {
        SlideSplitter.slideIndex(at: characterIndex, in: slides, text: text)
    }
}
