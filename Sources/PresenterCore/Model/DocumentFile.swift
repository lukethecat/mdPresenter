import Foundation

// MARK: - Document settings

public enum ColorMode: String, Codable, CaseIterable {
    case dark
    case light
}

public enum AspectRatio: String, Codable, CaseIterable, Identifiable {
    case responsive
    case wide169
    case wide1610
    case classic43
    case mobile916
    case portrait45
    case square11

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .responsive: return "Responsive"
        case .wide169: return "Wide 16:9"
        case .wide1610: return "Wide 16:10"
        case .classic43: return "Regular 4:3"
        case .mobile916: return "Mobile 9:16"
        case .portrait45: return "Portrait 4:5"
        case .square11: return "Square 1:1"
        }
    }

    /// Fixed ratio; nil for Responsive.
    public var ratio: CGFloat? {
        switch self {
        case .responsive: return nil
        case .wide169: return 16.0 / 9.0
        case .wide1610: return 16.0 / 10.0
        case .classic43: return 4.0 / 3.0
        case .mobile916: return 9.0 / 16.0
        case .portrait45: return 4.0 / 5.0
        case .square11: return 1.0
        }
    }
}

public struct DeckSettings: Codable, Equatable {
    public var themeId: String = "la"
    public var colorMode: ColorMode = .light
    public var aspect: AspectRatio = .responsive
    /// Custom headline font family override (nil = theme default).
    public var headlineFont: String? = nil
    /// Custom accent override as hex string (nil = theme default).
    public var accentHex: String? = nil
    public var headerText: String = ""
    public var footerText: String = ""
    public var showPageNumber: Bool = true

    public init() {}
}

// MARK: - Media attachments

public struct MediaAttachment: Codable, Equatable, Identifiable {
    public var id: String
    public var fileName: String
    public var mime: String
    public var data: Data

    public init(id: String = UUID().uuidString, fileName: String, mime: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.mime = mime
        self.data = data
    }

    public var isImage: Bool { mime.hasPrefix("image/") }
    public var isVideo: Bool { mime.hasPrefix("video/") }
    public var isAudio: Bool { mime.hasPrefix("audio/") }

    /// Markdown reference used inside the document.
    public var markdownRef: String { "media://\(id)" }
}

// MARK: - Document file (`.presenter`)

public struct DocumentFile: Codable {
    public static let currentFormatVersion = 1
    public var formatVersion: Int = DocumentFile.currentFormatVersion
    public var title: String
    public var markdown: String
    public var settings: DeckSettings
    public var media: [MediaAttachment]

    public init(title: String, markdown: String, settings: DeckSettings = DeckSettings(), media: [MediaAttachment] = []) {
        self.title = title
        self.markdown = markdown
        self.settings = settings
        self.media = media
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> DocumentFile {
        try JSONDecoder().decode(DocumentFile.self, from: data)
    }

    public func media(withId id: String) -> MediaAttachment? {
        media.first { $0.id == id }
    }

    public func media(for block: Block) -> MediaAttachment? {
        guard let ref = block.mediaRef, ref.hasPrefix("media://") else { return nil }
        return media(withId: String(ref.dropFirst("media://".count)))
    }
}

public extension Block {
    var mediaId: String? {
        guard let ref = mediaRef, ref.hasPrefix("media://") else { return nil }
        return String(ref.dropFirst("media://".count))
    }
}
