import Foundation

// MARK: - Inline AST

public enum Inline: Equatable {
    case text(String)
    case bold([Inline])
    case italic([Inline])
    case code(String)
    case link(text: [Inline], url: String)
    case lineBreak

    public var plainText: String {
        switch self {
        case .text(let s): return s
        case .bold(let kids): return kids.map { $0.plainText }.joined()
        case .italic(let kids): return kids.map { $0.plainText }.joined()
        case .code(let s): return s
        case .link(let kids, _): return kids.map { $0.plainText }.joined()
        case .lineBreak: return " "
        }
    }
}

public extension Array where Element == Inline {
    var plainText: String { map { $0.plainText }.joined() }
}

// MARK: - Block AST

public enum BlockKind: String {
    case heading
    case paragraph      // spoken text / body
    case bulletList
    case orderedList
    case quote
    case fencedCode
    case image
    case video
    case audio
    case table
    case rule
}

public struct Block: Equatable {
    public var kind: BlockKind
    /// Heading level 1...6.
    public var level: Int = 0
    /// Raw textual content (markers stripped) — for lists, one entry per item.
    public var lines: [String] = []
    /// Parsed inline content of the first/main line (headings, paragraphs).
    public var inlines: [Inline] = []
    /// For images/media: markdown `media://<id>` or an absolute path / URL.
    public var mediaRef: String?
    /// For images: alt text.
    public var alt: String = ""
    /// For code: language hint.
    public var language: String = ""
    /// For tables: grid of cells, first row is the header.
    public var rows: [[String]] = []
    /// For tables: per-column alignment from the separator row ("l"/"c"/"r").
    public var columnAlignments: [String] = []
    /// True when the paragraph was explicitly forced onto the slide with a leading tab.
    public var isTabbedOnSlide: Bool = false
    /// iA Presenter image metadata (`x:`, `y:`, `size:`, `title:`, …).
    public var metadata: [String: String] = [:]

    public init(kind: BlockKind) { self.kind = kind }

    public var plainText: String {
        switch kind {
        case .heading, .paragraph, .quote:
            return inlines.plainText
        case .bulletList, .orderedList:
            return lines.joined(separator: " ")
        case .fencedCode:
            return lines.joined(separator: "\n")
        case .image, .video, .audio:
            return alt
        case .table:
            return rows.flatMap { $0 }.joined(separator: " ")
        case .rule:
            return ""
        }
    }

    public var isMedia: Bool {
        kind == .image || kind == .video || kind == .audio
    }
}

// MARK: - Slide model

public struct Slide: Equatable {
    /// Raw markdown text of this slide (exactly what lives between separators).
    public var source: String = ""
    /// 0-based index of the slide's first line in the whole document.
    public var startLine: Int = 0
    /// Number of lines the slide occupies in the document.
    public var lineCount: Int = 0
    /// Parsed blocks in document order.
    public var blocks: [Block] = []
}

public extension Slide {
    var headings: [Block] { blocks.filter { $0.kind == .heading } }
    var firstHeading: Block? { headings.first }
    var media: [Block] { blocks.filter { $0.isMedia } }
    var tables: [Block] { blocks.filter { $0.kind == .table } }
    var codeBlocks: [Block] { blocks.filter { $0.kind == .fencedCode } }
    var spokenBlocks: [Block] {
        blocks.filter {
            switch $0.kind {
            case .paragraph, .bulletList, .orderedList, .quote:
                return !$0.isTabbedOnSlide
            default:
                return false
            }
        }
    }
    var onSlideBlocks: [Block] {
        blocks.filter {
            switch $0.kind {
            case .heading, .image, .video, .audio, .table, .fencedCode:
                return true
            case .paragraph, .bulletList, .orderedList, .quote:
                return $0.isTabbedOnSlide
            case .rule:
                return false
            }
        }
    }
}
