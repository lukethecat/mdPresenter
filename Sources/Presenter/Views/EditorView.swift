import AppKit
import Combine
import SwiftUI
import PresenterCore

// MARK: - Editor chrome colors (iA Writer night palette)

enum EditorChrome {
    static let background = NSColor(hex: 0x1B1C1F)
    static let text = NSColor(hex: 0xD9D9D6)
    static let dim = NSColor(hex: 0x6E7279)
    static let dimmer = NSColor(hex: 0x4A4D53)
    static let amber = NSColor(hex: 0xFFD479)
    static let lineColor = NSColor(hex: 0x2A2C31)
    static let heading = NSColor(hex: 0xF5F4F0)
    static let gutterBG = NSColor(hex: 0x1B1C1F)
}

// MARK: - The text view

final class MarkdownTextView: NSTextView {

    struct GutterSlide {
        let startChar: Int
        let color: NSColor
        let number: Int
        let isCurrent: Bool
    }

    var gutterSlides: [GutterSlide] = []
    var currentSlideGlyphRange: NSRange = NSRange(location: 0, length: 0)
    var onGutterClick: ((Int) -> Void)?
    var onTurboPaste: (() -> Void)?
    var onImagePaste: ((Data) -> Void)?

    private let monoFamily = Typography.editorFamily

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawCurrentSlideHighlight()
        drawGutter()
    }

    private func drawCurrentSlideHighlight() {
        guard currentSlideGlyphRange.length > 0,
              let lm = layoutManager, let tc = textContainer else { return }
        let glyphRange = lm.glyphRange(
            forCharacterRange: currentSlideGlyphRange, actualCharacterRange: nil
        )
        guard glyphRange.length > 0 else { return }
        var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        rect.origin.x = 0
        rect.size.width = bounds.width
        rect = rect.insetBy(dx: 0, dy: -6)
        NSColor.white.withAlpha(0.028).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
    }

    private func drawGutter() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        let insetX = textContainerInset.width

        // Hairline separating the gutter.
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: insetX - 14, y: 0))
        linePath.line(to: NSPoint(x: insetX - 14, y: bounds.height))
        EditorChrome.lineColor.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        for slide in gutterSlides {
            let charRange = NSRange(location: slide.startChar, length: 1)
            let glyphRange = lm.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { continue }
            let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            let y = rect.minY + rect.height * 0.28

            let circleRect = NSRect(x: 8, y: y, width: 20, height: 20)
            let path = NSBezierPath(ovalIn: circleRect)
            slide.color.withAlpha(slide.isCurrent ? 1.0 : 0.9).setFill()
            path.fill()
            if slide.isCurrent {
                NSColor.white.withAlpha(0.25).setStroke()
                path.lineWidth = 2
                path.stroke()
            }

            let label = "\(slide.number)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: slide.color.luminance > 0.5 ? NSColor(hex: 0x1B1C1F) : NSColor.white,
            ]
            let size = label.size(withAttributes: attrs)
            label.draw(
                at: NSPoint(x: circleRect.midX - size.width / 2, y: circleRect.midY - size.height / 2 - 0.5),
                withAttributes: attrs
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.x < textContainerInset.width - 12 {
            let idx = characterIndex(at: point)
            onGutterClick?(idx)
            return
        }
        super.mouseDown(with: event)
    }

    func characterIndex(at point: NSPoint) -> Int {
        guard let lm = layoutManager, let tc = textContainer else { return 0 }
        let glyph = lm.glyphIndex(for: point, in: tc, fractionOfDistanceThroughGlyph: nil)
        return lm.characterIndexForGlyph(at: glyph)
    }

    override func paste(_ sender: Any?) {
        // Pasted images become slide media.
        let pb = NSPasteboard.general
        if let imgData = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            onImagePaste?(imgData)
            return
        }
        if let pasted = pb.string(forType: .string) {
            let paragraphs = pasted
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if paragraphs.count >= 3 && !TurboStart.hasSeparators(pasted) {
                super.paste(sender)
                onTurboPaste?()
                return
            }
        }
        super.paste(sender)
    }
}

// MARK: - SwiftUI representable

struct EditorView: NSViewRepresentable {
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        // The editor sits ON liquid glass — no opaque background of its own.
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.borderType = .noBorder

        let tv = MarkdownTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = true
        tv.isContinuousSpellCheckingEnabled = false
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textColor = EditorChrome.text
        tv.insertionPointColor = .white
        tv.textContainerInset = NSSize(width: 52, height: 40)
        tv.font = Typography.editorFont

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5.5
        tv.defaultParagraphStyle = paragraph

        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.allowsDocumentBackgroundColorChange = false

        tv.onGutterClick = { [weak state] charIndex in
            guard let state = state else { return }
            let slides = SlideSplitter.split(state.text)
            if let idx = SlideSplitter.slideIndex(at: charIndex, in: slides, text: state.text as NSString) {
                state.selectSlide(idx)
                // The gutter belongs to the editor — keep the caret here.
                state.editorCommand.send(.focusEditor)
            }
        }
        tv.onTurboPaste = { [weak state] in
            state?.turboBanner = true
        }
        tv.onImagePaste = { [weak state] data in
            // TIFF → PNG for clean storage.
            var payload = data
            if let rep = NSBitmapImageRep(data: data),
               let png = rep.representation(using: .png, properties: [:]) {
                payload = png
            }
            state?.attachMedia(data: payload, fileName: "粘贴图片.png", mime: "image/png")
        }

        tv.string = state.text
        context.coordinator.textView = tv

        scroll.documentView = tv
        tv.frame = NSRect(
            x: 0, y: 0,
            width: max(scroll.contentView.bounds.width, 300),
            height: max(scroll.contentView.bounds.height, 600)
        )

        context.coordinator.installSubscriptions()
        context.coordinator.applyStyles()
        context.coordinator.updateGutter()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.state = state
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var state: AppState
        weak var textView: MarkdownTextView?
        private var cancellables = Set<AnyCancellable>()
        private var lastSlideIndex: Int = -1

        init(state: AppState) {
            self.state = state
        }

        func installSubscriptions() {
            cancellables.removeAll()
            state.editorCommand
                .receive(on: RunLoop.main)
                .sink { [weak self] command in
                    self?.handle(command)
                }
                .store(in: &cancellables)

            state.$currentSlide
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.applyStyles()
                    self?.updateGutter()
                    self?.textView?.needsDisplay = true
                }
                .store(in: &cancellables)

            state.$focusMode
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.applyStyles()
                    self?.textView?.needsDisplay = true
                }
                .store(in: &cancellables)
        }

        func handle(_ command: EditorCommand) {
            guard let tv = textView else { return }
            switch command {
            case .replaceText(let t):
                if tv.string != t {
                    tv.string = t
                    applyStyles()
                    updateGutter()
                }
            case .wrapSelection(let marker, let placeholder):
                let range = tv.selectedRange()
                if range.length == 0 {
                    tv.insertText(marker + placeholder + marker, replacementRange: range)
                    let inserted = NSRange(location: range.location + marker.count, length: placeholder.count)
                    tv.setSelectedRange(inserted)
                } else {
                    let selected = (tv.string as NSString).substring(with: range)
                    tv.insertText(marker + selected + marker, replacementRange: range)
                    tv.setSelectedRange(NSRange(location: range.location, length: selected.count + marker.count * 2))
                }
            case .prefixSelection(let marker):
                let range = tv.selectedRange()
                let ns = tv.string as NSString
                let lineRange = ns.lineRange(for: range)
                let lines = ns.substring(with: lineRange)
                let prefixed = lines
                    .components(separatedBy: "\n")
                    .map { $0.hasPrefix(marker) ? $0 : marker + $0 }
                    .joined(separator: "\n")
                tv.insertText(prefixed, replacementRange: lineRange)
                tv.setSelectedRange(NSRange(location: lineRange.location, length: prefixed.count))
            case .scrollToSlide(let idx):
                scroll(toSlide: idx)
            case .focusEditor:
                tv.window?.makeFirstResponder(tv)
            }
        }

        func scroll(toSlide idx: Int) {
            guard let tv = textView else { return }
            let slides = SlideSplitter.split(tv.string)
            guard slides.indices.contains(idx) else { return }
            let range = SlideSplitter.firstLineRange(of: slides[idx], in: tv.string as NSString)
            tv.scrollRangeToVisible(range)
            tv.setSelectedRange(NSRange(location: range.location, length: 0))
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? MarkdownTextView else { return }
            state.text = tv.string
            updateInsertionColor(tv)
            applyStyles()
            updateGutter()
            tv.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? MarkdownTextView else { return }
            let range = tv.selectedRange()
            state.selection = range
            updateInsertionColor(tv)
            let slides = SlideSplitter.split(tv.string)
            if let idx = SlideSplitter.slideIndex(at: range.location, in: slides, text: tv.string as NSString) {
                if idx != lastSlideIndex {
                    lastSlideIndex = idx
                    state.setCursorSlide(idx)
                }
            }
        }

        private func updateInsertionColor(_ tv: NSTextView) {
            let length = max(1, (tv.string as NSString).length)
            let progress = Double(tv.selectedRange().location) / Double(length)
            tv.insertionPointColor = ProgressColorEngine.color(at: progress)
        }

        // MARK: Styles (markdown syntax highlighting + focus)

        func applyStyles() {
            guard let tv = textView, let lm = tv.layoutManager else { return }
            let ns = tv.string as NSString
            let full = NSRange(location: 0, length: ns.length)
            lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            lm.removeTemporaryAttribute(.font, forCharacterRange: full)
            lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
            lm.removeTemporaryAttribute(.obliqueness, forCharacterRange: full)
            guard ns.length > 0 else { return }

            let slides = SlideSplitter.split(ns as String)
            let currentIdx = state.currentSlide
            let bodyFont = Typography.editorFont
            let headFont = NSFont(name: Typography.editorFamily, size: 18)
                ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)

            var lineIndex = 0
            var lineNumber = 0
            var slidePtr = 0
            var headingSeenInSlide = false

            while lineIndex < ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: lineIndex, length: 0))
                lineIndex = NSMaxRange(lineRange)
                guard lineRange.length > 0 else { continue }
                lineNumber += 1
                let rawLine = ns.substring(with: lineRange)
                let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                // Advance the slide pointer as we walk down the document.
                while slidePtr < slides.count - 1, lineNumber >= slides[slidePtr + 1].startLine {
                    slidePtr += 1
                    headingSeenInSlide = false
                }
                let slideForLine: Int? = slides.isEmpty ? nil : min(slidePtr, slides.count - 1)

                let inCurrent = slideForLine == currentIdx
                let progressColor = slideForLine.map { idx in
                    ProgressColorEngine.color(
                        at: slides.count > 1 ? Double(idx) / Double(slides.count - 1) : 0
                    )
                }

                // Focus mode dims everything outside the current slide.
                if state.focusMode && !inCurrent {
                    lm.addTemporaryAttribute(
                        .foregroundColor, value: EditorChrome.dimmer,
                        forCharacterRange: lineRange
                    )
                }

                // Rule separators.
                if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                    lm.addTemporaryAttribute(
                        .foregroundColor, value: EditorChrome.dim,
                        forCharacterRange: lineRange
                    )
                    continue
                }

                // Headings.
                if let level = headingLevel(of: trimmed) {
                    let contentStart = rawLine.index(rawLine.startIndex, offsetBy: min(level, rawLine.count))
                    let content = String(rawLine[contentStart...]).trimmingCharacters(in: .whitespaces)
                    let markerLen = rawLine.count - content.count
                    let markerRange = NSRange(location: lineRange.location, length: markerLen)
                    let contentRange = NSRange(location: lineRange.location + markerLen, length: (content as NSString).length)

                    lm.addTemporaryAttribute(.foregroundColor, value: EditorChrome.dimmer, forCharacterRange: markerRange)
                    let color: NSColor
                    if slideForLine == currentIdx {
                        color = EditorChrome.heading
                    } else if !headingSeenInSlide, let pc = progressColor {
                        // Slide titles shift color with progress, like the cursor.
                        color = pc
                        headingSeenInSlide = true
                    } else {
                        color = EditorChrome.heading
                    }
                    lm.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: contentRange)
                    lm.addTemporaryAttribute(.font, value: headFont, forCharacterRange: contentRange)
                    continue
                }

                // Quotes.
                if trimmed.hasPrefix(">") {
                    lm.addTemporaryAttribute(
                        .foregroundColor, value: EditorChrome.dim,
                        forCharacterRange: lineRange
                    )
                    lm.addTemporaryAttribute(
                        .backgroundColor, value: NSColor.white.withAlpha(0.03),
                        forCharacterRange: lineRange
                    )
                }

                // Inline markup.
                applyInlineStyles(on: lineRange, in: lm, bodyFont: bodyFont, dimmed: state.focusMode && !inCurrent)
            }
        }

        private func headingLevel(of trimmed: String) -> Int? {
            var level = 0
            for ch in trimmed {
                if ch == "#" { level += 1 } else { break }
            }
            guard level >= 1, level <= 6 else { return nil }
            let rest = trimmed.dropFirst(level)
            guard rest.isEmpty || rest.hasPrefix(" ") || rest.hasPrefix("\t") else { return nil }
            return level
        }

        private func applyInlineStyles(on lineRange: NSRange, in lm: NSLayoutManager, bodyFont: NSFont, dimmed: Bool) {
            guard let tv = textView else { return }
            let ns = tv.string as NSString
            let line = ns.substring(with: lineRange)
            let dimColor = dimmed ? EditorChrome.dimmer : EditorChrome.dim
            let boldFont = NSFont(name: Typography.editorFamily, size: bodyFont.pointSize)
                ?? bodyFont
            let boldFontB = NSFontManager.shared.convert(boldFont, toHaveTrait: .boldFontMask)

            func applyPattern(_ pattern: String, markerLen: Int, attributes: [NSAttributedString.Key: Any], contentAttributes: [NSAttributedString.Key: Any] = [:]) {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
                let matches = regex.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length))
                for match in matches.reversed() {
                    guard match.numberOfRanges >= 3 else { continue }
                    let marker1 = NSRange(location: lineRange.location + match.range(at: 1).location, length: match.range(at: 1).length)
                    let content = NSRange(location: lineRange.location + match.range(at: 2).location, length: match.range(at: 2).length)
                    let marker2 = NSRange(location: lineRange.location + match.range(at: 3).location, length: match.range(at: 3).length)
                    _ = markerLen
                    lm.addTemporaryAttribute(.foregroundColor, value: dimColor, forCharacterRange: marker1)
                    lm.addTemporaryAttribute(.foregroundColor, value: dimColor, forCharacterRange: marker2)
                    for (key, value) in contentAttributes {
                        lm.addTemporaryAttribute(key, value: value, forCharacterRange: content)
                    }
                    for (key, value) in attributes {
                        lm.addTemporaryAttribute(key, value: value, forCharacterRange: content)
                    }
                }
            }

            // Bold **…**
            applyPattern(
                "(\\*\\*)(.+?)(\\*\\*)", markerLen: 2,
                attributes: [.font: boldFontB, .foregroundColor: EditorChrome.heading]
            )
            // Italic *…*
            applyPattern(
                "(?<!\\*)(\\*)([^*\\n]+?)(\\*)(?!\\*)", markerLen: 1,
                attributes: [.obliqueness: 0.18]
            )
            // Inline code `…`
            applyPattern(
                "(`)([^`\\n]+?)(`)", markerLen: 1,
                attributes: [.foregroundColor: EditorChrome.amber],
                contentAttributes: [.backgroundColor: NSColor.white.withAlpha(0.06)]
            )
            // Links [text](url)
            applyPattern(
                "(\\[)([^\\]]+?)(\\]\\()[^)]*\\))", markerLen: 1,
                attributes: [.foregroundColor: NSColor(hex: 0x7FB4FF), .underlineStyle: NSUnderlineStyle.single.rawValue]
            )

            // List markers dim.
            if let regex = try? NSRegularExpression(pattern: "^([ \\t]*(?:[-*+]|\\d+\\.)\\s)") {
                let range = NSRange(location: 0, length: (line as NSString).length)
                if let match = regex.firstMatch(in: line, range: range), match.numberOfRanges >= 2 {
                    let marker = NSRange(location: lineRange.location + match.range(at: 1).location, length: match.range(at: 1).length)
                    lm.addTemporaryAttribute(.foregroundColor, value: dimColor, forCharacterRange: marker)
                }
            }

            // Tab marker (forces text onto the slide).
            if line.hasPrefix("\t") {
                let tabRange = NSRange(location: lineRange.location, length: 1)
                lm.addTemporaryAttribute(
                    .backgroundColor,
                    value: LiquidGlassPalette.systemBlue.withAlpha(0.35),
                    forCharacterRange: tabRange
                )
            }
        }

        // MARK: Gutter

        func updateGutter() {
            guard let tv = textView else { return }
            let ns = tv.string as NSString
            let slides = SlideSplitter.split(ns as String)
            var gutter: [MarkdownTextView.GutterSlide] = []
            for (i, slide) in slides.enumerated() {
                let range = slide.characterRange(in: ns)
                let color = ProgressColorEngine.color(
                    at: slides.count > 1 ? Double(i) / Double(slides.count - 1) : 0
                )
                gutter.append(MarkdownTextView.GutterSlide(
                    startChar: range.location,
                    color: color,
                    number: i + 1,
                    isCurrent: i == state.currentSlide
                ))
            }
            tv.gutterSlides = gutter
            if slides.indices.contains(state.currentSlide) {
                tv.currentSlideGlyphRange = slides[state.currentSlide].characterRange(in: ns)
            } else {
                tv.currentSlideGlyphRange = NSRange(location: 0, length: 0)
            }
        }
    }
}
