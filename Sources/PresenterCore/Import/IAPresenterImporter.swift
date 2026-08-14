import Foundation

// MARK: - iA Presenter compatibility
//
// iA Presenter saves `.iapresenter` / `.presenter` BUNDLES (directories):
//
//   MyPresentation.iapresenter/
//   ├── assets/      # images & media
//   ├── info.json    # metadata (creatorIdentifier: net.ia.presenter)
//   └── text.md      # the markdown story
//
// The importer reads the bundle, rewrites `/assets/…` references into
// `media://…` attachments, and keeps iA's semantics (--- slide separators,
// tab-indented visible text/lists, bare image URLs, image metadata lines).

public struct IAPresenterImporter {

    /// Try to import an iA Presenter bundle. Returns nil when `url` is not
    /// an iA bundle (callers then fall back to other formats).
    /// Accepts both forms: an on-disk directory bundle AND a `.zip` archive
    /// (the official docs describe `.iapresenter` as "a .zip that includes
    /// your markdown presentation file and all your images").
    public static func document(from url: URL) throws -> DocumentFile? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true {
            return try importBundle(url)
        }
        // Single file: maybe a zipped bundle. Unzip with the system tool.
        let ext = url.pathExtension.lowercased()
        guard ext == "iapresenter" || ext == "presenter" else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ia-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let textURL = tempDir.appendingPathComponent("text.md")
        guard FileManager.default.fileExists(atPath: textURL.path) else { return nil }
        return try importBundle(tempDir)
    }

    private static func importBundle(_ url: URL) throws -> DocumentFile? {
        let textURL = url.appendingPathComponent("text.md")
        guard FileManager.default.fileExists(atPath: textURL.path) else { return nil }

        var markdown = try String(contentsOf: textURL, encoding: .utf8)
        let assetsDir = url.appendingPathComponent("assets")
        var media: [MediaAttachment] = []

        // Rewrite /assets/… and assets/… references into media:// attachments.
        let pattern = #"(?:\./)?/?assets/([A-Za-z0-9._%+\-]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(markdown.startIndex..., in: markdown)
            let matches = regex.matches(in: markdown, range: range)
            // Walk backwards so earlier replacements don't shift later ranges.
            for match in matches.reversed() {
                guard match.numberOfRanges >= 2,
                      let nameRange = Range(match.range(at: 1), in: markdown),
                      let fullRange = Range(match.range(at: 0), in: markdown) else { continue }
                let fileName = String(markdown[nameRange])
                let assetURL = assetsDir.appendingPathComponent(fileName)
                guard let data = try? Data(contentsOf: assetURL) else { continue }
                let attachment = MediaAttachment(
                    fileName: fileName,
                    mime: Self.mime(for: fileName),
                    data: data
                )
                media.append(attachment)
                // Rewrite as a standalone image so iA metadata lines attach.
                markdown.replaceSubrange(
                    fullRange,
                    with: "![\(fileName)](\(attachment.markdownRef))"
                )
            }
        }

        let title = url.deletingPathExtension().lastPathComponent
        return DocumentFile(title: title, markdown: markdown, settings: DeckSettings(), media: media)
    }

    /// Export our document back into the iA Presenter bundle format.
    public static func write(_ document: DocumentFile, to url: URL) throws {
        let bundleDir = url
        try FileManager.default.createDirectory(
            at: bundleDir, withIntermediateDirectories: true
        )
        let assetsDir = bundleDir.appendingPathComponent("assets")
        try FileManager.default.createDirectory(
            at: assetsDir, withIntermediateDirectories: true
        )

        // info.json — iA Presenter metadata template (version 2).
        let info: [String: Any] = [
            "creatorIdentifier": "net.ia.presenter",
            "net.ia.presenter": [:],
            "transient": false,
            "type": "net.daringfireball.markdown",
            "version": 2,
        ]
        let infoData = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])
        try infoData.write(to: bundleDir.appendingPathComponent("info.json"))

        // text.md with media:// refs rewritten back to /assets/…
        var markdown = document.markdown
        for attachment in document.media {
            let safeName = attachment.fileName
                .replacingOccurrences(of: "/", with: "-")
            let target = assetsDir.appendingPathComponent(safeName)
            try? attachment.data.write(to: target)
            markdown = markdown.replacingOccurrences(
                of: attachment.markdownRef,
                with: "/assets/\(safeName)"
            )
        }
        try markdown.data(using: .utf8)?
            .write(to: bundleDir.appendingPathComponent("text.md"))
    }

    static func mime(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "tif", "tiff": return "image/tiff"
        case "heic": return "image/heic"
        case "avif": return "image/avif"
        case "bmp": return "image/bmp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4v": return "video/x-m4v"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        case "flac": return "audio/flac"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
