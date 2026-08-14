import AppKit
import SwiftUI
import PresenterCore

// MARK: - Inline text rendering
//
// Concatenated Text views give us bold/italic/code/links without relying
// on AttributedString (which needs macOS 12).

struct InlineTextView: View {
    let inlines: [Inline]
    var baseSize: CGFloat
    var family: String
    var weight: Font.Weight = .regular
    var color: Color = .white
    var accent: Color? = nil
    var lineSpacing: CGFloat = 4

    var body: some View {
        text().lineSpacing(lineSpacing)
    }

    private func text() -> Text {
        build(inlines, parentBold: false).fontWeight(weight)
    }

    private func build(_ inlines: [Inline], parentBold: Bool) -> Text {
        var result = Text("")
        for inline in inlines {
            switch inline {
            case .text(let s):
                result = result + Text(s)
            case .bold(let kids):
                let inner = build(kids, parentBold: true)
                result = result + inner.fontWeight(.bold)
            case .italic(let kids):
                let inner = build(kids, parentBold: parentBold)
                result = result + inner.italic()
            case .code(let s):
                result = result + Text(s)
                    .font(.system(size: baseSize * 0.86, weight: .regular, design: .monospaced))
                    .foregroundColor(accent ?? color)
            case .superscript(let s):
                result = result + Text(s)
                    .font(.system(size: baseSize * 0.72, weight: .medium))
                    .baselineOffset(baseSize * 0.32)
            case .subscript(let s):
                result = result + Text(s)
                    .font(.system(size: baseSize * 0.72, weight: .medium))
                    .baselineOffset(-baseSize * 0.16)
            case .link(let kids, _):
                let inner = build(kids, parentBold: parentBold)
                result = result + inner.underline()
            case .lineBreak:
                result = result + Text("\n")
            }
        }
        // Apply the base font to EVERY segment — including plain text.
        // (Previously only bold/italic segments carried a font, so plain
        // headlines rendered at the tiny default size.)
        return result
            .font(.custom(family, size: baseSize))
            .foregroundColor(color)
    }
}

// MARK: - Media views

struct MediaBlockView: View {
    let block: Block
    let attachment: MediaAttachment?
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let attachment = attachment, attachment.isImage {
                if let image = NSImage(data: attachment.data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    fallback
                }
            } else if let attachment = attachment, attachment.isVideo {
                mediaTile(icon: "play.rectangle.fill", name: attachment.fileName)
            } else if let attachment = attachment, attachment.isAudio {
                mediaTile(icon: "waveform", name: attachment.fileName)
            } else {
                fallback
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var fallback: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.12))
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .light))
                if !block.alt.isEmpty {
                    Text(block.alt)
                        .font(.system(size: 13))
                }
            }
            .foregroundColor(.white.opacity(0.7))
        }
    }

    private func mediaTile(icon: String, name: String) -> some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.14))
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .medium))
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
            .foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - Table view
//
// iA Presenter-style minimal table: no heavy box — a semibold header on a
// hairline, thin row separators, proportional column widths (CJK-aware),
// numeric cells right-aligned, and inline markdown inside cells.

struct SlideTableView: View {
    let rows: [[String]]
    var alignments: [String] = []
    var textColor: Color
    var accent: Color
    var width: CGFloat
    var fontSize: CGFloat? = nil
    var maxRows: Int = 12

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<visibleRows.count, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { c in
                        cellView(row: visibleRows[r], column: c, isHeader: r == 0)
                    }
                }
                .padding(.vertical, cellFont * 0.55)
                if r < visibleRows.count - 1 {
                    Rectangle()
                        .fill(textColor.opacity(r == 0 ? 0.34 : 0.12))
                        .frame(height: 1)
                }
            }
        }
    }

    private var columns: Int { rows.map { $0.count }.max() ?? 1 }
    private var cellFont: CGFloat { fontSize ?? max(10, min(16, width / 48)) }
    private var visibleRows: [[String]] { Array(rows.prefix(max(3, maxRows))) }

    private func cellText(row: [String], column: Int) -> String {
        column < row.count ? row[column] : ""
    }

    /// Display width with CJK glyphs counting double.
    private func displayWidth(_ s: String) -> CGFloat {
        s.reduce(0) { acc, ch in
            acc + (ch.unicodeScalars.first.map { $0.value > 0x2E80 } ?? false ? 2 : 1)
        }
    }

    /// Column widths proportional to the widest cell in each column.
    private func columnWeights() -> [CGFloat] {
        var weights = [CGFloat](repeating: 1, count: columns)
        for row in rows {
            for (c, cell) in row.enumerated() where c < columns {
                weights[c] = max(weights[c], displayWidth(cell))
            }
        }
        let total = max(1, weights.reduce(0, +))
        return weights.map { max(0.14, $0 / total) }
    }

    private func alignment(for column: Int, cell: String) -> Alignment {
        // Explicit iA/markdown alignment hints win; numeric cells go right.
        if column < alignments.count {
            switch alignments[column] {
            case "c": return .center
            case "r": return .trailing
            default: break
            }
        }
        let cleaned = cell.replacingOccurrences(of: ",", with: "")
        if !cell.isEmpty, Double(cleaned) != nil { return .trailing }
        return .leading
    }

    private func cellView(row: [String], column: Int, isHeader: Bool) -> some View {
        let cell = cellText(row: row, column: column)
        return InlineTextView(
            inlines: MarkdownParser.parseInline(cell),
            baseSize: cellFont,
            family: "Helvetica Neue",
            weight: isHeader ? .semibold : .regular,
            color: textColor,
            lineSpacing: 0
        )
        .lineLimit(2)
        .frame(
            width: width * columnWeights()[column],
            alignment: alignment(for: column, cell: cell)
        )
        .padding(.horizontal, 8)
    }
}

// MARK: - The slide canvas
//
// One renderer for every context: editor preview, thumbnails, presenter,
// and PDF/PNG export. All sizes derive from the canvas geometry, so the
// same view scales from a 120pt thumbnail to a projector.

struct SlideCanvas: View {
    let content: SlideContent
    let style: SlideStyle
    let settings: DeckSettings
    let media: [MediaAttachment]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                background(width: w, height: h)
                headerFooter(width: w, height: h)
                slideBody(width: w, height: h)
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: Background

    @ViewBuilder
    private func background(width: CGFloat, height: CGFloat) -> some View {
        if style.background.count >= 2 {
            LinearGradient(
                gradient: Gradient(colors: style.background.map { Color($0) }),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color(style.background.first ?? .white)
        }
    }

    // MARK: Header / footer

    @ViewBuilder
    private func headerFooter(width: CGFloat, height: CGFloat) -> some View {
        VStack {
            // Header
            HStack(alignment: .top) {
                if !settings.headerText.isEmpty {
                    Text(settings.headerText)
                        .font(.system(size: max(9, width * 0.014), weight: .medium))
                        .foregroundColor(Color(style.pageColor))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, width * 0.05)
            .padding(.top, height * 0.035)

            Spacer()

            // Footer
            HStack(alignment: .bottom) {
                if !settings.footerText.isEmpty {
                    Text(settings.footerText)
                        .font(.system(size: max(9, width * 0.014), weight: .regular))
                        .foregroundColor(Color(style.pageColor))
                        .lineLimit(1)
                }
                Spacer()
                if settings.showPageNumber {
                    Text("\(content.index + 1) / \(max(1, content.total))")
                        .font(.system(size: max(9, width * 0.014), weight: .regular))
                        .foregroundColor(Color(style.pageColor))
                }
            }
            .padding(.horizontal, width * 0.05)
            .padding(.bottom, height * 0.03)
        }
    }

    // MARK: Body

    @ViewBuilder
    private func slideBody(width: CGFloat, height: CGFloat) -> some View {
        switch content.layout {
        case .title: titleLayout(width: width, height: height)
        case .statement: statementLayout(width: width, height: height)
        case .quote: quoteLayout(width: width, height: height)
        case .split: splitLayout(width: width, height: height)
        case .mediaFull: mediaFullLayout(width: width, height: height)
        case .grid: gridLayout(width: width, height: height)
        case .table: tableLayout(width: width, height: height)
        case .columns: columnsLayout(width: width, height: height)
        case .empty: emptyLayout(width: width, height: height)
        }
    }

    // MARK: Layouts

    private func titleLayout(width: CGFloat, height: CGFloat) -> some View {
        let text = content.title?.plainText ?? "无标题"
        let subtitle = content.subtitle?.plainText ?? ""
        let box = CGSize(width: width * 0.84, height: height * (subtitle.isEmpty ? 0.62 : 0.5))
        let size = LayoutEngine.fitFontSize(
            text: text, family: style.headlineFamily, weight: style.headlineWeight,
            maxSize: width / 8, minSize: 22, in: box
        )
        return VStack(alignment: alignment, spacing: height * 0.03) {
            if let kicker = content.kicker {
                kickerText(kicker.plainText, width: width, baseSize: width * 0.02)
            }
            Text(text)
                .font(.custom(style.headlineFamily, size: size))
                .fontWeight(swiftWeight(style.headlineWeight))
                .foregroundColor(Color(style.headlineColor))
                .minimumScaleFactor(0.5)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty {
                Rectangle()
                    .fill(Color(style.accent))
                    .frame(width: width * 0.1, height: max(2, height * 0.006))
                Text(subtitle)
                    .font(.custom(style.headlineFamily, size: max(14, size * 0.32)))
                    .fontWeight(.regular)
                    .foregroundColor(Color(style.textColor).opacity(0.92))
                    .lineLimit(3)
            }
        }
        .frame(width: width * 0.84, alignment: alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private func statementLayout(width: CGFloat, height: CGFloat) -> some View {
        let text = content.headline?.plainText ?? "幻灯片 \(content.index + 1)"
        let box = CGSize(width: width * 0.86, height: height * 0.6)
        let size = LayoutEngine.fitFontSize(
            text: text, family: style.headlineFamily, weight: style.headlineWeight,
            maxSize: width / 6.5, minSize: 20, in: box
        )
        return VStack(alignment: alignment, spacing: height * 0.03) {
            if let kicker = content.kicker {
                kickerText(kicker.plainText, width: width, baseSize: width * 0.022)
            }
            InlineTextView(
                inlines: content.headline?.inlines ?? [],
                baseSize: size,
                family: style.headlineFamily,
                weight: swiftWeight(style.headlineWeight),
                color: Color(style.headlineColor)
            )
            .minimumScaleFactor(0.5)
            .lineLimit(5)
        }
        .frame(maxWidth: width * 0.9, alignment: alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private func quoteLayout(width: CGFloat, height: CGFloat) -> some View {
        let headline = content.headline?.plainText ?? ""
        let headlineBox = CGSize(width: width * 0.86, height: height * 0.38)
        let headSize = LayoutEngine.fitFontSize(
            text: headline, family: style.headlineFamily, weight: style.headlineWeight,
            maxSize: width / 7, minSize: 18, in: headlineBox
        )
        let support = content.onSlide.filter { $0.isTabbedOnSlide }
        return VStack(alignment: alignment, spacing: height * 0.03) {
            if let kicker = content.kicker {
                kickerText(kicker.plainText, width: width, baseSize: width * 0.022)
            }
            InlineTextView(
                inlines: content.headline?.inlines ?? [],
                baseSize: headSize,
                family: style.headlineFamily,
                weight: swiftWeight(style.headlineWeight),
                color: Color(style.headlineColor)
            )
            .lineLimit(3)
            Rectangle()
                .fill(Color(style.accent))
                .frame(width: width * 0.08, height: max(2, height * 0.005))
            ForEach(Array(support.enumerated()), id: \.offset) { _, block in
                InlineTextView(
                    inlines: block.inlines,
                    baseSize: max(13, headSize * 0.3),
                    family: style.headlineFamily,
                    color: Color(style.textColor)
                )
                .lineLimit(4)
            }
        }
        .frame(maxWidth: width * 0.86, alignment: alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private func splitLayout(width: CGFloat, height: CGFloat) -> some View {
        let mediaBlocks = content.onSlide.filter { $0.isMedia }
        let mediaBlock = mediaBlocks.first
        let textBlocks = content.onSlide.filter { $0.isTabbedOnSlide }
        let narrow = width < height * 1.05

        if narrow {
            // Stacked on narrow (portrait) canvases.
            VStack(spacing: height * 0.02) {
                headlineBlock(width: width, height: height * 0.3)
                if let mb = mediaBlock {
                    MediaBlockView(block: mb, attachment: attachment(for: mb))
                        .frame(maxWidth: width * 0.8, maxHeight: height * 0.5)
                }
                supportText(textBlocks, width: width, baseSize: width * 0.024)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, height * 0.08)
        } else {
            HStack(spacing: width * 0.04) {
                VStack(alignment: .leading, spacing: height * 0.02) {
                    headlineBlock(width: width * 0.42, height: height * 0.5)
                    supportText(textBlocks, width: width * 0.42, baseSize: width * 0.018)
                    Spacer()
                }
                .frame(width: width * 0.42, alignment: .leading)
                if let mb = mediaBlock {
                    MediaBlockView(block: mb, attachment: attachment(for: mb))
                        .frame(maxWidth: width * 0.5, maxHeight: height * 0.82)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, width * 0.05)
            .padding(.vertical, height * 0.09)
        }
    }

    @ViewBuilder
    private func headlineBlock(width: CGFloat, height: CGFloat) -> some View {
        let text = content.headline?.plainText ?? ""
        let size = LayoutEngine.fitFontSize(
            text: text, family: style.headlineFamily, weight: style.headlineWeight,
            maxSize: width / 5, minSize: 16, in: CGSize(width: width, height: height)
        )
        VStack(alignment: .leading, spacing: height * 0.02) {
            if let kicker = content.kicker {
                kickerText(kicker.plainText, width: width, baseSize: width * 0.02)
            }
            InlineTextView(
                inlines: content.headline?.inlines ?? [],
                baseSize: size,
                family: style.headlineFamily,
                weight: swiftWeight(style.headlineWeight),
                color: Color(style.headlineColor)
            )
            .lineLimit(4)
        }
    }

    @ViewBuilder
    private func supportText(_ blocks: [Block], width: CGFloat, baseSize: CGFloat) -> some View {
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            InlineTextView(
                inlines: block.inlines,
                baseSize: baseSize,
                family: style.headlineFamily,
                color: Color(style.textColor)
            )
            .lineLimit(3)
        }
    }

    private func mediaFullLayout(width: CGFloat, height: CGFloat) -> some View {
        let mediaBlock = content.onSlide.filter { $0.isMedia }.first
        return VStack(spacing: height * 0.02) {
            if let mb = mediaBlock {
                MediaBlockView(block: mb, attachment: attachment(for: mb))
                    .frame(maxWidth: width * 0.92, maxHeight: height * 0.72)
            }
            if let headline = content.headline {
                InlineTextView(
                    inlines: headline.inlines,
                    baseSize: max(13, width * 0.028),
                    family: style.headlineFamily,
                    weight: swiftWeight(style.headlineWeight),
                    color: Color(style.headlineColor)
                )
                .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, height * 0.07)
    }

    private func gridLayout(width: CGFloat, height: CGFloat) -> some View {
        let mediaBlocks = Array(content.onSlide.filter { $0.isMedia }.prefix(4))
        let cols = mediaBlocks.count == 1 ? 1 : 2
        let rows = mediaBlocks.count > 2 ? 2 : 1
        let theHeadline = content.headline
        return VStack(spacing: height * 0.02) {
            if let headline = theHeadline {
                InlineTextView(
                    inlines: headline.inlines,
                    baseSize: max(14, width * 0.03),
                    family: style.headlineFamily,
                    weight: swiftWeight(style.headlineWeight),
                    color: Color(style.headlineColor)
                )
                .lineLimit(2)
            }
            VStack(spacing: height * 0.02) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: width * 0.02) {
                        ForEach(0..<cols, id: \.self) { c in
                            let idx = r * cols + c
                            if idx < mediaBlocks.count {
                                MediaBlockView(block: mediaBlocks[idx], attachment: attachment(for: mediaBlocks[idx]))
                                    .frame(
                                        maxWidth: (width * 0.86) / CGFloat(cols),
                                        maxHeight: (height * 0.6) / CGFloat(rows)
                                    )
                            } else {
                                Color.clear.frame(
                                    maxWidth: (width * 0.86) / CGFloat(cols),
                                    maxHeight: (height * 0.6) / CGFloat(rows)
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, height * 0.07)
    }

    /// iA Presenter multi-column: each heading + its tabbed text becomes a
    /// side-by-side column.
    private func columnsLayout(width: CGFloat, height: CGFloat) -> some View {
        // Group the on-slide blocks into heading-led columns, in order.
        var columns: [(head: Block, texts: [Block])] = []
        for block in content.onSlide {
            if block.kind == .heading {
                columns.append((head: block, texts: []))
            } else if block.isTabbedOnSlide {
                if columns.isEmpty {
                    columns.append((head: Block(kind: .heading), texts: [block]))
                } else {
                    columns[columns.count - 1].texts.append(block)
                }
            }
        }
        let visible = Array(columns.prefix(3))
        let columnWidth = width * 0.84 / CGFloat(max(1, visible.count))
        return HStack(alignment: .top, spacing: width * 0.03) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, column in
                VStack(alignment: .leading, spacing: height * 0.02) {
                    let headText = column.head.plainText
                    if !headText.isEmpty {
                        let headSize = LayoutEngine.fitFontSize(
                            text: headText, family: style.headlineFamily, weight: style.headlineWeight,
                            maxSize: width / 12, minSize: 16,
                            in: CGSize(width: columnWidth * 0.92, height: height * 0.3)
                        )
                        InlineTextView(
                            inlines: column.head.inlines,
                            baseSize: headSize,
                            family: style.headlineFamily,
                            weight: swiftWeight(style.headlineWeight),
                            color: Color(style.headlineColor)
                        )
                        .lineLimit(2)
                        Rectangle()
                            .fill(Color(style.accent))
                            .frame(width: columnWidth * 0.16, height: max(2, height * 0.005))
                    }
                    ForEach(Array(column.texts.enumerated()), id: \.offset) { _, textBlock in
                        InlineTextView(
                            inlines: textBlock.inlines,
                            baseSize: max(13, width * 0.02),
                            family: style.headlineFamily,
                            color: Color(style.textColor)
                        )
                        .lineLimit(6)
                    }
                }
                .frame(width: columnWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, height * 0.08)
    }

    private func tableLayout(width: CGFloat, height: CGFloat) -> some View {
        let table = content.onSlide.first { $0.kind == .table }
        let headline = content.headline?.plainText ?? ""
        let tableWidth = width * 0.84
        // Scale the table to the canvas: the headline gets up to ~22% of
        // the height, the table the rest — rows are capped so it never
        // overflows the slide.
        let cellFont = max(10, min(16, tableWidth / 44))
        let headlineBudget = headline.isEmpty ? 0 : height * 0.24
        let tableBudget = height * 0.62 - headlineBudget
        let maxRows = max(2, Int(tableBudget / (cellFont * 2.3)))
        return VStack(alignment: .leading, spacing: height * 0.03) {
            if !headline.isEmpty {
                let size = LayoutEngine.fitFontSize(
                    text: headline, family: style.headlineFamily, weight: style.headlineWeight,
                    maxSize: width / 8, minSize: 16,
                    in: CGSize(width: tableWidth, height: headlineBudget * 0.9)
                )
                InlineTextView(
                    inlines: content.headline?.inlines ?? [],
                    baseSize: size,
                    family: style.headlineFamily,
                    weight: swiftWeight(style.headlineWeight),
                    color: Color(style.headlineColor)
                )
                .lineLimit(2)
            }
            SlideTableView(
                rows: table?.rows ?? [],
                alignments: table?.columnAlignments ?? [],
                textColor: Color(style.textColor),
                accent: Color(style.accent),
                width: tableWidth,
                fontSize: cellFont,
                maxRows: maxRows
            )
            .frame(width: tableWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, height * 0.08)
    }

    private func emptyLayout(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: height * 0.02) {
            Text("\(content.index + 1)")
                .font(.system(size: width * 0.045, weight: .ultraLight))
                .foregroundColor(Color(style.textColor).opacity(0.25))
            Text("空白幻灯片 — 写下一个标题")
                .font(.system(size: max(11, width * 0.016), weight: .regular))
                .foregroundColor(Color(style.textColor).opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private var alignment: HorizontalAlignment {
        style.centerContent ? .center : .leading
    }

    private var frameAlignment: Alignment {
        .center
    }

    /// Map AppKit font weights onto SwiftUI weights (macOS 11-safe).
    private func swiftWeight(_ weight: NSFont.Weight) -> Font.Weight {
        switch weight {
        case .black: return .black
        case .heavy: return .heavy
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .light: return .light
        case .thin, .ultraLight: return .thin
        default: return .regular
        }
    }

    private func kickerText(_ text: String, width: CGFloat, baseSize: CGFloat) -> some View {
        Text(style.uppercaseKicker ? text.uppercased() : text)
            .font(.system(size: max(10, baseSize), weight: .semibold))
            .tracking(style.uppercaseKicker ? width * 0.006 : 0)
            .foregroundColor(Color(style.kickerColor))
            .lineLimit(1)
    }

    private func attachment(for block: Block) -> MediaAttachment? {
        guard let id = block.mediaId else { return nil }
        return media.first { $0.id == id }
    }
}
