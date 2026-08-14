import Foundation

// MARK: - Markdown parsing engine
//
// A focused, hand-rolled CommonMark-subset parser tuned for presentations:
// headings, paragraphs, lists, quotes, fenced code, tables, images and
// inline emphasis/code/links. The output feeds the content/presentation
// splitter and the slide renderer.

public struct MarkdownParser {

    public static func parseBlocks(_ source: String) -> [Block] {
        let text = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Pre-pass: collect reference-link and footnote DEFINITIONS and
        // remove them from the text — they are metadata, never notes.
        var linkDefs: [String: String] = [:]
        var footnoteDefs: [String] = []
        let lines = text.components(separatedBy: "\n").filter { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            if let def = footnoteDefinition(t) {
                footnoteDefs.append(def)
                return false
            }
            if let def = linkDefinition(t) {
                linkDefs[def.0] = def.1
                return false
            }
            return true
        }

        var blocks = parseBlockLines(lines, links: linkDefs)

        // Footnotes are grouped at the end of the slide and land in notes.
        if !footnoteDefs.isEmpty {
            var foot = Block(kind: .bulletList)
            foot.lines = footnoteDefs.enumerated().map { "\($0.offset + 1). \($0.element)" }
            blocks.append(foot)
        }
        return blocks
    }

    private static func parseBlockLines(_ lines: [String], links: [String: String]) -> [Block] {
        var blocks: [Block] = []
        var i = 0

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty { i += 1; continue }

            // Display math $$…$$ or \[…\] — rendered as a math code block.
            if let math = parseDisplayMath(line) {
                blocks.append(math)
                i += 1
                continue
            }

            // Fenced code
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let fence = line.hasPrefix("```") ? "```" : "~~~"
                var lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count {
                    let l = lines[i]
                    if l.trimmingCharacters(in: .whitespaces).hasPrefix(fence) { i += 1; break }
                    code.append(l)
                    i += 1
                }
                var block = Block(kind: .fencedCode)
                block.lines = code
                block.language = lang
                blocks.append(block)
                continue
            }

            // ATX heading
            if let heading = parseHeading(line, links: links) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Table (needs a following separator row)
            if line.contains("|") && i + 1 < lines.count && isTableSeparator(lines[i + 1]) {
                let alignments = parseTableAlignments(lines[i + 1])
                var rows: [[String]] = [splitTableRow(line)]
                i += 2
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.contains("|") && !l.isEmpty {
                        rows.append(splitTableRow(l))
                        i += 1
                    } else {
                        break
                    }
                }
                var block = Block(kind: .table)
                block.rows = rows
                block.columnAlignments = alignments
                // iA table caption: a [Caption] line directly below the table.
                if i < lines.count,
                   let caption = tableCaption(lines[i]) {
                    block.metadata["caption"] = caption
                    i += 1
                }
                blocks.append(block)
                continue
            }

            // Blockquote (iA: a leading tab makes the quote visible)
            if line.hasPrefix(">") {
                let tabbed = raw.hasPrefix("\t")
                var quoteLines: [String] = []
                while i < lines.count {
                    let l = lines[i]
                    let t = l.trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    let content = t.hasPrefix("> ") ? String(t.dropFirst(2)) : String(t.dropFirst())
                    quoteLines.append(content)
                    i += 1
                }
                var block = Block(kind: .quote)
                block.lines = quoteLines
                block.isTabbedOnSlide = tabbed
                block.inlines = quoteLines
                    .map { parseInline($0, links: links) }
                    .reduce(into: []) { partial, inl in
                        if !partial.isEmpty { partial.append(.lineBreak) }
                        partial.append(contentsOf: inl)
                    }
                blocks.append(block)
                continue
            }

            // Unordered list (iA: a leading tab makes the whole list visible)
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                let tabbed = raw.hasPrefix("\t")
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") else { break }
                    items.append(taskListItem(String(t.dropFirst(2))))
                    i += 1
                }
                var block = Block(kind: .bulletList)
                block.lines = items
                block.isTabbedOnSlide = tabbed
                blocks.append(block)
                continue
            }

            // Ordered list (iA: a leading tab makes the whole list visible)
            if isOrderedListItem(line) {
                let tabbed = raw.hasPrefix("\t")
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isOrderedListItem(t) else { break }
                    if let idx = t.firstIndex(of: ".") {
                        items.append(taskListItem(String(t[t.index(after: idx)...]).trimmingCharacters(in: .whitespaces)))
                    } else {
                        items.append(taskListItem(t))
                    }
                    i += 1
                }
                var block = Block(kind: .orderedList)
                block.lines = items
                block.isTabbedOnSlide = tabbed
                blocks.append(block)
                continue
            }

            // Horizontal rule inside a slide (rare — the splitter consumes `---`)
            if line == "---" || line == "***" || line == "___" {
                blocks.append(Block(kind: .rule))
                i += 1
                continue
            }

            // Standalone image: ![alt](ref)
            if let media = parseStandaloneImage(line) {
                i += 1
                var block = media
                block.metadata = consumeImageMetadata(lines: lines, from: &i)
                blocks.append(block)
                continue
            }

            // HTML image tag: <img src="…">
            if let htmlImage = parseHTMLImage(line) {
                blocks.append(htmlImage)
                i += 1
                continue
            }

            // iA Presenter: a bare image URL or local path on its own line
            // (https://example.com/a.png, /assets/photo.jpg) is a visible image.
            if isBareImageLine(line) {
                var block = Block(kind: .image)
                block.mediaRef = line
                block.alt = (line as NSString).lastPathComponent
                i += 1
                block.metadata = consumeImageMetadata(lines: lines, from: &i)
                blocks.append(block)
                continue
            }

            // Paragraph (possibly several lines, possibly tabbed onto the slide)
            let tabbed = raw.hasPrefix("\t")
            var paraLines: [String] = []
            while i < lines.count {
                let t = lines[i]
                let trimmed = t.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || startsBlock(trimmed) { break }
                paraLines.append(t)
                i += 1
            }
            var block = Block(kind: .paragraph)
            block.isTabbedOnSlide = tabbed
            var inlines: [Inline] = []
            for (n, pl) in paraLines.enumerated() {
                var content = (n == 0 && tabbed && pl.hasPrefix("\t")) ? String(pl.dropFirst()) : pl
                // iA: a backslash or two trailing spaces on the PREVIOUS line
                // force a hard break; otherwise lines flow into one paragraph.
                if n > 0 {
                    let prev = paraLines[n - 1]
                    if prev.hasSuffix("\\") || prev.hasSuffix("  ") {
                        inlines.append(.lineBreak)
                    } else {
                        inlines.append(.text(" "))
                    }
                }
                if content.hasSuffix("\\") { content = String(content.dropLast()) }
                // iA definition lists: "⇥: definition" renders as visible text.
                if content.hasPrefix(": ") { content = String(content.dropFirst(2)) }
                inlines.append(contentsOf: parseInline(content, links: links))
            }
            block.inlines = inlines
            blocks.append(block)
        }
        return blocks
    }

    public static func parse(_ source: String) -> Slide {
        var slide = Slide(source: source)
        slide.blocks = parseBlocks(source)
        return slide
    }

    // MARK: - Block helpers

    static func startsBlock(_ trimmedLine: String) -> Bool {
        if trimmedLine.hasPrefix("#") { return true }
        if trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~") { return true }
        if trimmedLine.hasPrefix(">") { return true }
        if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") { return true }
        if trimmedLine.hasPrefix("|") { return true }
        if isOrderedListItem(trimmedLine) { return true }
        if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" { return true }
        if isBareImageLine(trimmedLine) { return true }
        return false
    }

    /// iA Presenter: a bare image URL or local path on its own line is a
    /// visible image (https://…/a.png, /assets/photo.jpg, media://…).
    static func isBareImageLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.hasPrefix("media://") { return true }
        // URLs may carry query strings/fragments — check the path part.
        var path = lower
        if let q = path.firstIndex(of: "?") { path = String(path[..<q]) }
        if let f = path.firstIndex(of: "#") { path = String(path[..<f]) }
        let hasImageExtension = path.range(
            of: "\\.(png|jpe?g|gif|webp|svg|tiff?|heic|avif|bmp)$",
            options: .regularExpression
        ) != nil
        guard hasImageExtension else { return false }
        return path.hasPrefix("http://") || path.hasPrefix("https://")
            || line.hasPrefix("/") || line.hasPrefix(".")
    }

    /// iA Presenter image metadata lines (`x:`, `y:`, `size:`, `title:`, …)
    /// directly following an image belong to it — never to speaker notes.
    static func consumeImageMetadata(lines: [String], from i: inout Int) -> [String: String] {
        let knownKeys = ["x", "y", "size", "background", "filter", "opacity", "title"]
        var metadata: [String: String] = [:]
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            guard let colon = t.firstIndex(of: ":"), !t.isEmpty, t.startIndex < colon else { break }
            let key = String(t[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            guard knownKeys.contains(key) else { break }
            var value = String(t[t.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            metadata[key] = value
            i += 1
        }
        return metadata
    }

    static func parseHeading(_ line: String, links: [String: String] = [:]) -> Block? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1 && level <= 6 else { return nil }
        let rest = line.dropFirst(level)
        guard rest.isEmpty || rest.hasPrefix(" ") || rest.hasPrefix("\t") else { return nil }
        var block = Block(kind: .heading)
        block.level = level
        block.inlines = parseInline(String(rest).trimmingCharacters(in: .whitespaces), links: links)
        return block
    }

    /// iA display math: `$$…$$` or `\[…\]` on its own line(s).
    static func parseDisplayMath(_ line: String) -> Block? {
        if line.hasPrefix("$$"), line.hasSuffix("$$"), line.count >= 4 {
            var block = Block(kind: .fencedCode)
            block.language = "math"
            block.lines = [String(line.dropFirst(2).dropLast(2))]
            return block
        }
        if line.hasPrefix("\\["), line.hasSuffix("\\]"), line.count >= 4 {
            var block = Block(kind: .fencedCode)
            block.language = "math"
            block.lines = [String(line.dropFirst(2).dropLast(2))]
            return block
        }
        return nil
    }

    /// Reference link definition: `[id]: https://…`
    static func linkDefinition(_ line: String) -> (String, String)? {
        guard line.hasPrefix("["), !line.hasPrefix("[^") else { return nil }
        guard let close = line.firstIndex(of: "]") else { return nil }
        let rest = line[line.index(after: close)...]
        guard rest.hasPrefix(":") else { return nil }
        let id = String(line[line.index(after: line.startIndex)..<close]).trimmingCharacters(in: .whitespaces)
        let url = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !url.isEmpty else { return nil }
        return (id, url)
    }

    /// Footnote definition: `[^id]: text`
    static func footnoteDefinition(_ line: String) -> String? {
        guard line.hasPrefix("[^") else { return nil }
        guard let close = line.firstIndex(of: "]") else { return nil }
        let rest = line[line.index(after: close)...]
        guard rest.hasPrefix(":") else { return nil }
        let text = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// HTML image tag: `<img src="…">`
    static func parseHTMLImage(_ line: String) -> Block? {
        guard line.lowercased().hasPrefix("<img") else { return nil }
        guard let srcRange = line.range(
            of: #"src="[^"]+""#,
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }
        var src = String(line[srcRange])
        src = String(src.dropFirst(5).dropLast()) // strip src=" and "
        guard !src.isEmpty else { return nil }
        var block = Block(kind: .image)
        block.mediaRef = src
        block.alt = (src as NSString).lastPathComponent
        return block
    }

    /// iA task lists: `- [ ]` → "☐", `- [x]` → "☑".
    static func taskListItem(_ item: String) -> String {
        if item.hasPrefix("[ ] ") { return "☐ " + String(item.dropFirst(4)) }
        if item.hasPrefix("[x] ") { return "☑ " + String(item.dropFirst(4)) }
        return item
    }

    static func isOrderedListItem(_ line: String) -> Bool {
        var digits = 0
        for ch in line {
            if ch.isNumber { digits += 1 } else { break }
        }
        guard digits >= 1 else { return false }
        let rest = line.dropFirst(digits)
        return rest.hasPrefix(". ") || rest == "."
    }

    static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.contains("|"), t.contains("-") else { return false }
        let cells = t.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
        }
    }

    static func splitTableRow(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        var cells = t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        // iA cell merging: a trailing `|` (e.g. `| Gift | 0$ ||`) merges
        // into the previous cell — collapse trailing empties.
        while cells.count > 1, cells.last?.isEmpty == true {
            cells.removeLast()
        }
        return cells
    }

    /// Column alignments from the separator row (`|:---|`, `|---:|`, `|:---:|`).
    static func parseTableAlignments(_ separator: String) -> [String] {
        var t = separator.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { cell in
            let s = cell.trimmingCharacters(in: .whitespaces)
            let left = s.hasPrefix(":")
            let right = s.hasSuffix(":")
            if left && right { return "c" }
            if right { return "r" }
            return "l"
        }
    }

    /// iA table caption: a standalone `[Caption text]` line below the table
    /// (not a reference link `[id]: url`, not a footnote `[^id]:`, not a
    /// reference usage `[text][id]`).
    static func tableCaption(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("["), t.hasSuffix("]"), t.count > 2, !t.hasPrefix("[^") else { return nil }
        let inner = String(t.dropFirst().dropLast())
        guard !inner.isEmpty, !inner.contains("["), !inner.contains("]") else { return nil }
        return inner
    }

    static func parseStandaloneImage(_ line: String) -> Block? {
        // ![alt](ref) with nothing else on the line
        guard line.hasPrefix("![") else { return nil }
        guard let close = line.firstIndex(of: "]") else { return nil }
        let rest = line[line.index(after: close)...]
        guard rest.hasPrefix("("), rest.hasSuffix(")") else { return nil }
        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<close])
        let ref = String(rest.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        var block = Block(kind: .image)
        block.alt = alt
        block.mediaRef = ref
        return block
    }

    // MARK: - Inline parser

    public static func parseInline(_ input: String, links: [String: String] = [:]) -> [Inline] {
        var result: [Inline] = []
        var i = input.startIndex
        var buffer = ""

        func flushBuffer() {
            if !buffer.isEmpty {
                result.append(.text(buffer))
                buffer = ""
            }
        }

        while i < input.endIndex {
            let ch = input[i]
            if ch == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    buffer.append(input[next])
                    i = input.index(after: next)
                    continue
                }
                buffer.append(ch)
                i = next
                continue
            }
            if ch == "`" {
                // code span
                var end = input.index(after: i)
                var code = ""
                var found = false
                while end < input.endIndex {
                    if input[end] == "`" {
                        found = true
                        break
                    }
                    code.append(input[end])
                    end = input.index(after: end)
                }
                if found {
                    flushBuffer()
                    result.append(.code(code))
                    i = input.index(after: end)
                    continue
                }
            }
            if ch == "!" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "[" {
                    // link with image marker inside text — treat as link text
                    buffer.append("!")
                    i = next
                    continue
                }
            }
            // iA inline math $…$ (no space inside) → code-styled text.
            if ch == "$" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] != " ", input[next] != "$" {
                    var j = next
                    var content = ""
                    while j < input.endIndex, input[j] != "$" {
                        content.append(input[j])
                        j = input.index(after: j)
                    }
                    if j < input.endIndex, !content.isEmpty {
                        flushBuffer()
                        result.append(.code(content))
                        i = input.index(after: j)
                        continue
                    }
                }
            }
            // iA superscript: 100m^2 or y^(a+b)^
            if ch == "^" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    if input[next] == "(" {
                        var j = input.index(after: next)
                        var content = ""
                        while j < input.endIndex, input[j] != ")" {
                            content.append(input[j])
                            j = input.index(after: j)
                        }
                        if j < input.endIndex, !content.isEmpty {
                            flushBuffer()
                            result.append(.superscript(content))
                            i = input.index(after: j)
                            continue
                        }
                    } else {
                        var j = next
                        var content = ""
                        while j < input.endIndex, input[j].isLetter || input[j].isNumber {
                            content.append(input[j])
                            j = input.index(after: j)
                        }
                        if !content.isEmpty {
                            flushBuffer()
                            result.append(.superscript(content))
                            i = j
                            continue
                        }
                    }
                }
            }
            // iA subscript: x~z or x~y,z~ (single tilde; ~~ is strikethrough)
            if ch == "~" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] != "~", input[next] != " " {
                    var j = next
                    var content = ""
                    var found = false
                    // delimited form first: no whitespace inside
                    while j < input.endIndex {
                        if input[j] == "~" {
                            found = true
                            break
                        }
                        if input[j].isWhitespace { break }
                        content.append(input[j])
                        j = input.index(after: j)
                    }
                    if found, !content.isEmpty {
                        flushBuffer()
                        result.append(.subscript(content))
                        i = input.index(after: j)
                        continue
                    }
                    // bare run form: x~z
                    j = next
                    content = ""
                    while j < input.endIndex, input[j].isLetter || input[j].isNumber {
                        content.append(input[j])
                        j = input.index(after: j)
                    }
                    if !content.isEmpty {
                        flushBuffer()
                        result.append(.subscript(content))
                        i = j
                        continue
                    }
                }
            }
            if ch == "[" {
                // iA inline footnote [^text]
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "^" {
                    var j = input.index(after: next)
                    var content = ""
                    while j < input.endIndex, input[j] != "]" {
                        content.append(input[j])
                        j = input.index(after: j)
                    }
                    if j < input.endIndex {
                        flushBuffer()
                        result.append(.superscript("†"))
                        i = input.index(after: j)
                        continue
                    }
                }
                if let link = parseLink(from: input, start: i) {
                    flushBuffer()
                    result.append(.link(text: parseInline(link.0, links: links), url: link.1))
                    i = link.2
                    continue
                }
                // iA reference link [text][id] / [text][]
                if let ref = parseReferenceLink(from: input, start: i, links: links) {
                    flushBuffer()
                    result.append(.link(text: parseInline(ref.0, links: links), url: ref.1))
                    i = ref.2
                    continue
                }
            }
            // iA strikethrough ~~text~~ → rendered as oblique (no dedicated style).
            if ch == "~" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "~" {
                    if let strike = parseEmphasis(from: input, start: i, marker: "~~") {
                        flushBuffer()
                        result.append(.italic(parseInline(strike.0, links: links)))
                        i = strike.1
                        continue
                    }
                }
            }
            // iA highlight ==text== → rendered as bold.
            if ch == "=" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "=" {
                    if let highlight = parseEmphasis(from: input, start: i, marker: "==") {
                        flushBuffer()
                        result.append(.bold(parseInline(highlight.0, links: links)))
                        i = highlight.1
                        continue
                    }
                }
            }
            if ch == "*" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "*" {
                    if let bold = parseEmphasis(from: input, start: i, marker: "**") {
                        flushBuffer()
                        result.append(.bold(parseInline(bold.0, links: links)))
                        i = bold.1
                        continue
                    }
                } else if let italic = parseEmphasis(from: input, start: i, marker: "*") {
                    flushBuffer()
                    result.append(.italic(parseInline(italic.0, links: links)))
                    i = italic.1
                    continue
                }
            }
            if ch == "_" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "_" {
                    if let bold = parseEmphasis(from: input, start: i, marker: "__") {
                        flushBuffer()
                        result.append(.bold(parseInline(bold.0, links: links)))
                        i = bold.1
                        continue
                    }
                } else if let italic = parseEmphasis(from: input, start: i, marker: "_") {
                    flushBuffer()
                    result.append(.italic(parseInline(italic.0, links: links)))
                    i = italic.1
                    continue
                }
            }
            buffer.append(ch)
            i = input.index(after: i)
        }
        flushBuffer()
        return result
    }

    /// Returns (inner, endIndex-after-closing-marker) or nil.
    static func parseEmphasis(from input: String, start: String.Index, marker: String) -> (String, String.Index)? {
        var i = input.index(start, offsetBy: marker.count)
        var content = ""
        while i < input.endIndex {
            if input[i] == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    content.append(input[next])
                    i = input.index(after: next)
                    continue
                }
            }
            if input[i...].hasPrefix(marker) {
                let after = input.index(i, offsetBy: marker.count)
                // Don't close on an empty emphasis.
                if !content.isEmpty { return (content, after) }
            }
            content.append(input[i])
            i = input.index(after: i)
        }
        return nil
    }

    /// Returns (text, url, endIndex) or nil.
    static func parseLink(from input: String, start: String.Index) -> (String, String, String.Index)? {
        var i = input.index(after: start)
        var text = ""
        while i < input.endIndex {
            if input[i] == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    text.append(input[next])
                    i = input.index(after: next)
                    continue
                }
            }
            if input[i] == "]" {
                let afterBracket = input.index(after: i)
                if afterBracket < input.endIndex, input[afterBracket] == "(" {
                    var j = input.index(after: afterBracket)
                    var url = ""
                    while j < input.endIndex {
                        if input[j] == ")" {
                            if !text.isEmpty && !url.isEmpty {
                                return (text, url, input.index(after: j))
                            }
                            return nil
                        }
                        url.append(input[j])
                        j = input.index(after: j)
                    }
                }
                return nil
            }
            text.append(input[i])
            i = input.index(after: i)
        }
        return nil
    }

    /// iA reference link: [text][id] or [text][] (id falls back to the text).
    static func parseReferenceLink(
        from input: String, start: String.Index, links: [String: String]
    ) -> (String, String, String.Index)? {
        var i = input.index(after: start)
        var text = ""
        while i < input.endIndex {
            if input[i] == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    text.append(input[next])
                    i = input.index(after: next)
                    continue
                }
            }
            if input[i] == "]" {
                let after = input.index(after: i)
                guard after < input.endIndex, input[after] == "[" else { return nil }
                var j = input.index(after: after)
                var id = ""
                while j < input.endIndex {
                    if input[j] == "]" {
                        let key = id.isEmpty ? text : id
                        guard let url = links[key] else { return nil }
                        return (text, url, input.index(after: j))
                    }
                    id.append(input[j])
                    j = input.index(after: j)
                }
                return nil
            }
            text.append(input[i])
            i = input.index(after: i)
        }
        return nil
    }
}
