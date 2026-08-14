import XCTest
@testable import PresenterCore

final class ContentResolverTests: XCTestCase {

    func testHeadlineOnSlideBodyInNotes() {
        let slide = MarkdownParser.parse("# 主题\n这是给演讲者看的备注，观众不会看到。")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 3)
        XCTAssertEqual(content.headline?.plainText, "主题")
        XCTAssertTrue(content.notesPlain.contains("这是给演讲者看的备注"))
        XCTAssertFalse(content.onSlide.contains { $0.kind == .paragraph && !$0.isTabbedOnSlide })
    }

    func testTitleSlide() {
        let slide = MarkdownParser.parse("# 大标题\n## 副标题\n开场白备注")
        let content = ContentResolver.resolve(slide: slide, index: 0, total: 3)
        XCTAssertTrue(content.isTitleSlide)
        XCTAssertEqual(content.title?.plainText, "大标题")
        XCTAssertEqual(content.subtitle?.plainText, "副标题")
        XCTAssertEqual(content.layout, .title)
        XCTAssertTrue(content.notesPlain.contains("开场白备注"))
    }

    func testTabForcesTextOnSlide() {
        let slide = MarkdownParser.parse("# 标题\n\t这句话会出现在幻灯片上")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 3)
        XCTAssertTrue(content.onSlide.contains { $0.isTabbedOnSlide })
        XCTAssertEqual(content.notes.count, 0)
    }

    func testMediaPicksSplitLayout() {
        let slide = MarkdownParser.parse("# 配图标题\n![图](media://img-1)")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 3)
        XCTAssertEqual(content.layout, .split)
    }

    func testMultipleImagesPickGrid() {
        let slide = MarkdownParser.parse("![a](media://1)\n\n![b](media://2)")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 3)
        XCTAssertEqual(content.layout, .grid)
    }

    func testKickerFromThirdLevelHeading() {
        let slide = MarkdownParser.parse("# 主标题\n\n### 章节")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 3)
        XCTAssertEqual(content.headline?.plainText, "主标题")
        XCTAssertEqual(content.kicker?.plainText, "章节")
    }

    func testEmptySlide() {
        let slide = Slide(source: "只有备注没有标题")
        let parsed = MarkdownParser.parse(slide.source)
        let content = ContentResolver.resolve(slide: parsed, index: 2, total: 3)
        XCTAssertEqual(content.layout, .empty)
        XCTAssertNil(content.headline)
    }

    func testProgressDistribution() {
        let a = ContentResolver.resolve(slide: Slide(source: ""), index: 0, total: 3)
        let b = ContentResolver.resolve(slide: Slide(source: ""), index: 1, total: 3)
        let c = ContentResolver.resolve(slide: Slide(source: ""), index: 2, total: 3)
        XCTAssertEqual(a.progress, 0)
        XCTAssertEqual(b.progress, 0.5)
        XCTAssertEqual(c.progress, 1)
    }
}
