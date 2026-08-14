import XCTest
@testable import PresenterCore

// MARK: - Full iA Presenter markdown coverage
//
// Tests for the syntax documented at ia.net/presenter/support/basics/markdown.

final class IAMarkdownCoverageTests: XCTestCase {

    func testHardLineBreaks() {
        // Two trailing spaces or a trailing backslash force a break;
        // otherwise lines flow into one paragraph.
        let hard = MarkdownParser.parseBlocks("line one  \nline two")
        XCTAssertTrue(hard[0].inlines.contains(.lineBreak))
        let backslash = MarkdownParser.parseBlocks("line one\\\nline two")
        XCTAssertTrue(backslash[0].inlines.contains(.lineBreak))
        XCTAssertFalse(backslash[0].plainText.contains("\\"), "marker must be stripped")
        let soft = MarkdownParser.parseBlocks("line one\nline two")
        XCTAssertFalse(soft[0].inlines.contains(.lineBreak))
        XCTAssertEqual(soft[0].plainText, "line one line two")
    }

    func testTaskLists() {
        let blocks = MarkdownParser.parseBlocks("- [ ] Milk\n- [x] Bread")
        XCTAssertEqual(blocks[0].lines, ["☐ Milk", "☑ Bread"])
    }

    func testTabbedBlockquoteIsVisible() {
        let slide = MarkdownParser.parse("\t> 可见引用\n\n备注")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 2)
        XCTAssertTrue(content.onSlide.contains { $0.kind == .quote && $0.isTabbedOnSlide })
        XCTAssertFalse(content.notesPlain.contains("可见引用"))
    }

    func testSuperscriptAndSubscript() {
        let inlines = MarkdownParser.parseInline("100m^2 与 x~z 与 y^(a+b)^ 与 x~y,z~")
        XCTAssertTrue(inlines.contains { if case .superscript("2") = $0 { return true } else { return false } })
        XCTAssertTrue(inlines.contains { if case .superscript("a+b") = $0 { return true } else { return false } })
        XCTAssertTrue(inlines.contains { if case .subscript("z") = $0 { return true } else { return false } })
        XCTAssertTrue(inlines.contains { if case .subscript("y,z") = $0 { return true } else { return false } })
    }

    func testReferenceLinks() {
        let blocks = MarkdownParser.parseBlocks(
            "这是 [参考链接][id]。\n\n[id]: https://example.com"
        )
        XCTAssertTrue(blocks[0].inlines.contains { if case .link(_, "https://example.com") = $0 { return true } else { return false } })
        XCTAssertFalse(blocks.map { $0.plainText }.joined().contains("[id]:"), "definition must be hidden")

        let omitted = MarkdownParser.parseBlocks("[Google][]\n\n[Google]: https://google.com")
        XCTAssertTrue(omitted[0].inlines.contains { if case .link(_, "https://google.com") = $0 { return true } else { return false } })
    }

    func testFootnotes() {
        let blocks = MarkdownParser.parseBlocks(
            "正文包含脚注[^第一条]。\n\n[^第一条]: 脚注内容。"
        )
        // Inline footnote becomes a superscript marker, definition is hidden
        // and grouped into the notes.
        XCTAssertFalse(blocks.map { $0.plainText }.joined().contains("[^第一条]:"))
        XCTAssertTrue(blocks.last?.kind == .bulletList)
        XCTAssertTrue(blocks.last?.lines.first?.contains("脚注内容") == true)
    }

    func testDefinitionLists() {
        let blocks = MarkdownParser.parseBlocks("\tMarkdown\n\t: 一种轻量级标记语言。")
        XCTAssertTrue(blocks.allSatisfy { $0.isTabbedOnSlide })
        XCTAssertTrue(blocks.last?.plainText.contains("一种轻量级标记语言") == true)
        XCTAssertFalse(blocks.last?.plainText.hasPrefix(":") ?? true, "colon marker stripped")
    }

    func testInlineMathBecomesCode() {
        let inlines = MarkdownParser.parseInline("公式 $x+y^2$ 结束")
        XCTAssertTrue(inlines.contains { if case .code(let s) = $0 { return s.contains("x+y") } else { return false } })
        XCTAssertFalse(inlines.plainText.contains("$"), "dollar signs stripped")
        // A lone dollar (price) is left alone.
        let price = MarkdownParser.parseInline("价格 10$")
        XCTAssertTrue(price.plainText.contains("10$"))
    }

    func testDisplayMath() {
        let blocks = MarkdownParser.parseBlocks("$$a+b=c$$")
        XCTAssertEqual(blocks[0].kind, .fencedCode)
        XCTAssertEqual(blocks[0].language, "math")
        XCTAssertEqual(blocks[0].lines, ["a+b=c"])
    }

    func testHTMLImageTag() {
        let blocks = MarkdownParser.parseBlocks("<img src=\"photo.png\">")
        XCTAssertEqual(blocks[0].kind, .image)
        XCTAssertEqual(blocks[0].mediaRef, "photo.png")
    }

    func testTableCellMerge() {
        let blocks = MarkdownParser.parseBlocks("| Name | Price | Tax |\n|:--|--:|--:|\n| Widget | 10$ | 1$ |\n| Gift | 0$ ||")
        XCTAssertEqual(blocks[0].rows[1], ["Widget", "10$", "1$"])
        XCTAssertEqual(blocks[0].rows[2], ["Gift", "0$"], "trailing || merges cells")
    }
}
