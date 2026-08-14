import Foundation

// MARK: - Markdown export

public struct MarkdownExporter {

    /// Plain markdown: slides separated by two blank lines (three Returns),
    /// plus a media appendix listing embedded attachments.
    public static func markdown(from document: DocumentFile) -> String {
        var out = document.markdown
        if !document.media.isEmpty {
            out += "\n\n\n---\n\n## 媒体附件\n\n"
            for m in document.media {
                out += "- \(m.fileName) — \(m.mime)\n"
            }
        }
        return out
    }

    /// A readable summary document: title, then per-slide headline + notes.
    public static func summary(from deck: Deck, title: String) -> String {
        var out = "# \(title)\n\n"
        for content in deck.contents {
            out += "\n\n\n## \(content.index + 1). "
            let headline = content.headline?.plainText ?? content.title?.plainText ?? "（无标题）"
            out += headline + "\n\n"
            if !content.notesPlain.isEmpty {
                out += content.notesPlain + "\n"
            }
        }
        return out
    }
}
