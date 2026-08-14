import XCTest
@testable import PresenterCore

final class MarkdownParserTests: XCTestCase {

    func testHeadings() {
        let blocks = MarkdownParser.parseBlocks("# Title\n## Sub\nNormal")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].kind, .heading)
        XCTAssertEqual(blocks[0].level, 1)
        XCTAssertEqual(blocks[0].plainText, "Title")
        XCTAssertEqual(blocks[1].kind, .heading)
        XCTAssertEqual(blocks[1].level, 2)
        XCTAssertEqual(blocks[2].kind, .paragraph)
        XCTAssertEqual(blocks[2].plainText, "Normal")
    }

    func testParagraphWithInlineFormatting() {
        let blocks = MarkdownParser.parseBlocks("Hello **bold** and *italic* and `code`.")
        XCTAssertEqual(blocks.count, 1)
        let inlines = blocks[0].inlines
        XCTAssertTrue(inlines.contains { if case .bold = $0 { return true } else { return false } })
        XCTAssertTrue(inlines.contains { if case .italic = $0 { return true } else { return false } })
        XCTAssertTrue(inlines.contains { if case .code = $0 { return true } else { return false } })
        XCTAssertEqual(blocks[0].plainText, "Hello bold and italic and code.")
    }

    func testLists() {
        let blocks = MarkdownParser.parseBlocks("- one\n- two\n\n1. first\n2. second")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].kind, .bulletList)
        XCTAssertEqual(blocks[0].lines, ["one", "two"])
        XCTAssertEqual(blocks[1].kind, .orderedList)
        XCTAssertEqual(blocks[1].lines, ["first", "second"])
    }

    func testQuote() {
        let blocks = MarkdownParser.parseBlocks("> wisdom\n> more")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .quote)
        XCTAssertEqual(blocks[0].plainText, "wisdom more")
    }

    func testFencedCode() {
        let blocks = MarkdownParser.parseBlocks("```swift\nlet x = 1\n```")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .fencedCode)
        XCTAssertEqual(blocks[0].language, "swift")
        XCTAssertEqual(blocks[0].lines, ["let x = 1"])
    }

    func testTable() {
        let blocks = MarkdownParser.parseBlocks("| A | B |\n|---|---|\n| 1 | 2 |")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .table)
        XCTAssertEqual(blocks[0].rows.count, 2)
        XCTAssertEqual(blocks[0].rows[0], ["A", "B"])
        XCTAssertEqual(blocks[0].rows[1], ["1", "2"])
    }

    func testStandaloneImage() {
        let blocks = MarkdownParser.parseBlocks("![a cat](media://cat-1)")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .image)
        XCTAssertEqual(blocks[0].alt, "a cat")
        XCTAssertEqual(blocks[0].mediaId, "cat-1")
    }

    func testTableAlignmentHints() {
        let blocks = MarkdownParser.parseBlocks("| A | B |\n|:---:|---:|\n| 1 | 2 |")
        XCTAssertEqual(blocks[0].kind, .table)
        XCTAssertEqual(blocks[0].columnAlignments, ["c", "r"])
    }

    /// 回归：没有分隔行的管道行曾导致解析器死循环（无限追加空段落，
    /// 2.6GB 内存/未响应）。现在必须被消费为普通段落或安全跳过。
    func testPipeLineWithoutSeparatorDoesNotHang() {
        let blocks = MarkdownParser.parseBlocks("| 指标 | 数值 |")
        XCTAssertLessThan(blocks.count, 3, "must terminate with bounded blocks")
        let blocks2 = MarkdownParser.parseBlocks("|")
        XCTAssertLessThan(blocks2.count, 3)
        let blocks3 = MarkdownParser.parseBlocks("| --- | --- |")
        XCTAssertLessThan(blocks3.count, 3)
    }

    func testBareImageURLWithQueryString() {
        let blocks = MarkdownParser.parseBlocks("https://example.com/photo.png?w=800#frag")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .image)
        XCTAssertEqual(blocks[0].mediaRef, "https://example.com/photo.png?w=800#frag")
    }

    func testTableCellsSupportInlineMarkup() {
        let blocks = MarkdownParser.parseBlocks("| A | B |\n|---|---|\n| **bold** | `code` |")
        XCTAssertEqual(blocks[0].rows[1][0], "**bold**")
        // Cell content keeps raw text; renderer parses inlines per cell.
        let inlines = MarkdownParser.parseInline(blocks[0].rows[1][0])
        XCTAssertEqual(inlines.plainText, "bold")
    }

    func testTabbedParagraphGoesOnSlide() {
        let blocks = MarkdownParser.parseBlocks("\tThis line must appear on the slide")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .paragraph)
        XCTAssertTrue(blocks[0].isTabbedOnSlide)
        XCTAssertEqual(blocks[0].plainText, "This line must appear on the slide")
    }

    func testCJKInline() {
        let blocks = MarkdownParser.parseBlocks("这是**加粗**的文字")
        XCTAssertEqual(blocks[0].plainText, "这是加粗的文字")
    }
}
