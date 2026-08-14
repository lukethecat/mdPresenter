import AppKit
import CoreText
import Foundation

// MARK: - Handout PDF export
//
// "After the show, export the story as a readable document." A clean,
// typeset summary: title page, then every slide's headline and speaker
// notes flowing as a structured document. Built on CoreText so it works
// without any UI.

public enum PDFExportError: Error {
    case cannotCreateContext
}

public struct HandoutPDFExporter {

    public struct Options {
        public var pageSize: CGSize
        public var margin: CGFloat
        public var title: String
        public var accent: NSColor
        public var fontFamily: String
        public var progressColors: Bool

        public init(
            pageSize: CGSize = CGSize(width: 595, height: 842), // A4
            margin: CGFloat = 56,
            title: String = "Presentation",
            accent: NSColor = NSColor(hex: 0x3B82F6),
            fontFamily: String = "Helvetica Neue",
            progressColors: Bool = true
        ) {
            self.pageSize = pageSize
            self.margin = margin
            self.title = title
            self.accent = accent
            self.fontFamily = fontFamily
            self.progressColors = progressColors
        }
    }

    public static func export(deck: Deck, options: Options) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw PDFExportError.cannotCreateContext
        }
        var mediaBox = CGRect(origin: .zero, size: options.pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFExportError.cannotCreateContext
        }

        let pages = buildPages(deck: deck, options: options)
        for (i, page) in pages.enumerated() {
            context.beginPDFPage(nil)
            draw(page: page, index: i, options: options, in: context)
            context.endPDFPage()
        }
        context.closePDF()

        return data as Data
    }

    // MARK: Pages

    struct TextRun {
        var text: String
        var font: NSFont
        var color: NSColor
        var paragraphSpacing: CGFloat
    }

    struct Page {
        var runs: [TextRun]
    }

    static func buildPages(deck: Deck, options: Options) -> [Page] {
        let titleFont = NSFont(name: options.fontFamily, size: 34)
            ?? NSFont.boldSystemFont(ofSize: 34)
        let headFont = NSFont(name: options.fontFamily, size: 19)
            ?? NSFont.boldSystemFont(ofSize: 19)
        let bodyFont = NSFont.systemFont(ofSize: 12.5)
        let smallFont = NSFont.systemFont(ofSize: 10.5)

        var pages: [Page] = []
        var runs: [TextRun] = []

        let maxHeight = options.pageSize.height - options.margin * 2
        let textWidth = options.pageSize.width - options.margin * 2
        var used: CGFloat = 0

        func estimateHeight(_ run: TextRun) -> CGFloat {
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacing = run.paragraphSpacing
            let attrs: [NSAttributedString.Key: Any] = [
                .font: run.font,
                .paragraphStyle: paragraph,
            ]
            let b = (run.text as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            return b.height + run.paragraphSpacing + 4
        }

        func add(_ run: TextRun) {
            let h = estimateHeight(run)
            if used + h > maxHeight && !runs.isEmpty {
                pages.append(Page(runs: runs))
                runs = []
                used = 0
            }
            runs.append(run)
            used += h
        }

        func addSpacer(_ h: CGFloat) {
            if used + h > maxHeight && !runs.isEmpty {
                pages.append(Page(runs: runs))
                runs = []
                used = 0
            }
            used += h
        }

        // Title page
        add(TextRun(text: options.title, font: titleFont, color: .black, paragraphSpacing: 18))
        add(TextRun(
            text: "\(deck.contents.count) slides · generated from Markdown",
            font: smallFont, color: NSColor(white: 0.45, alpha: 1), paragraphSpacing: 4
        ))
        addSpacer(maxHeight - used - 1)

        // One section per slide
        for content in deck.contents {
            let headline = content.headline?.plainText ?? content.title?.plainText ?? "Slide \(content.index + 1)"
            let color = options.progressColors
                ? ProgressColorEngine.color(at: content.progress)
                : options.accent
            add(TextRun(
                text: "\(content.index + 1) · \(headline)",
                font: headFont, color: color, paragraphSpacing: 8
            ))
            if !content.notesPlain.isEmpty {
                add(TextRun(
                    text: content.notesPlain,
                    font: bodyFont, color: NSColor(white: 0.2, alpha: 1), paragraphSpacing: 12
                ))
            } else {
                add(TextRun(
                    text: "—",
                    font: bodyFont, color: NSColor(white: 0.55, alpha: 1), paragraphSpacing: 12
                ))
            }
        }

        if !runs.isEmpty { pages.append(Page(runs: runs)) }
        return pages
    }

    // MARK: Drawing

    static func draw(page: Page, index: Int, options: Options, in context: CGContext) {
        // Paper
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: options.pageSize))

        // Footer
        let footer = "\(options.title) — page \(index + 1)"
        let fAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor(white: 0.6, alpha: 1),
        ]
        let fb = (footer as NSString).size(withAttributes: fAttrs)
        (footer as NSString).draw(
            at: CGPoint(x: options.margin, y: options.margin / 2),
            withAttributes: fAttrs
        )
        _ = fb

        // Runs via CoreText
        let textWidth = options.pageSize.width - options.margin * 2
        var y = options.pageSize.height - options.margin
        for run in page.runs {
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacing = run.paragraphSpacing
            let attrs: [NSAttributedString.Key: Any] = [
                .font: run.font,
                .foregroundColor: run.color,
                .paragraphStyle: paragraph,
            ]
            let attributed = NSAttributedString(string: run.text, attributes: attrs)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let path = CGPath(
                rect: CGRect(x: options.margin, y: 0, width: textWidth, height: .greatestFiniteMagnitude),
                transform: nil
            )
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            let height = frameHeight(frame)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: y)
            context.scaleBy(x: 1, y: -1)
            CTFrameDraw(frame, context)
            context.restoreGState()
            y -= height + run.paragraphSpacing
        }
    }

    static func frameHeight(_ frame: CTFrame) -> CGFloat {
        let lines = CTFrameGetLines(frame) as! [CTLine]
        guard !lines.isEmpty else { return 0 }
        var maxY: CGFloat = 0
        for line in lines {
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            maxY = max(maxY, ascent + descent + leading)
        }
        return maxY * CGFloat(lines.count) * 1.05
    }
}
