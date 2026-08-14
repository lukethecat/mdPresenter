import XCTest
import Foundation
@testable import PresenterCore

// MARK: - iA Presenter compatibility tests

final class IAPresenterImporterTests: XCTestCase {

    private var bundleURL: URL!

    override func setUpWithError() throws {
        bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).iapresenter")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: bundleURL.appendingPathComponent("assets"), withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: bundleURL)
    }

    private func makeBundle(text: String) throws {
        try text.data(using: .utf8)?.write(to: bundleURL.appendingPathComponent("text.md"))
        let info = """
        {
          "creatorIdentifier" : "net.ia.presenter",
          "net.ia.presenter" : {},
          "transient" : false,
          "type" : "net.daringfireball.markdown",
          "version" : 2
        }
        """
        try info.data(using: .utf8)?.write(to: bundleURL.appendingPathComponent("info.json"))
        // A tiny 1×1 PNG asset.
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        )!
        try png.write(to: bundleURL.appendingPathComponent("assets/pic.png"))
    }

    func testImportsIABundle() throws {
        try makeBundle(text: """
        # 主标题

        \t可见的副标题

        这是演讲备注，观众看不到。

        ---

        ### 要点

        \t可见列表：
        \t- 项目一
        \t- 项目二

        /assets/pic.png
        x: right
        title: "配图说明"

        https://example.com/photo.jpg

        隐藏备注。
        """)

        let doc = try XCTUnwrap(IAPresenterImporter.document(from: bundleURL))
        XCTAssertEqual(doc.title, bundleURL.deletingPathExtension().lastPathComponent)
        XCTAssertEqual(doc.media.count, 1)
        XCTAssertTrue(doc.media[0].mime.hasPrefix("image/png"))
        XCTAssertTrue(doc.markdown.contains("media://"), "asset path should be rewritten")

        let deck = Deck(text: doc.markdown)
        XCTAssertEqual(deck.slides.count, 2)

        let first = ContentResolver.resolve(slide: deck.slides[0], index: 0, total: 2)
        XCTAssertEqual(first.title?.plainText, "主标题")
        XCTAssertTrue(first.onSlide.contains { $0.isTabbedOnSlide })
        XCTAssertTrue(first.notesPlain.contains("这是演讲备注"))

        let second = ContentResolver.resolve(slide: deck.slides[1], index: 1, total: 2)
        // Tabbed list is VISIBLE content, not notes.
        XCTAssertTrue(second.onSlide.contains { $0.kind == .bulletList && $0.isTabbedOnSlide })
        XCTAssertFalse(second.notesPlain.contains("项目一"), "tabbed list must not be notes")
        // Bare URL becomes an image block.
        XCTAssertTrue(second.onSlide.contains { $0.isMedia && $0.mediaRef?.hasPrefix("https://") == true })
        // Metadata lines belong to the image, never to notes.
        XCTAssertFalse(second.notesPlain.contains("x: right"), "image metadata leaked into notes")
        XCTAssertFalse(second.notesPlain.contains("配图说明"), "image title leaked into notes")
        // Hidden plain paragraph stays in notes.
        XCTAssertTrue(second.notesPlain.contains("隐藏备注"))
    }

    func testNonIABundleReturnsNil() throws {
        let plainFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("plain-\(UUID().uuidString).md")
        try "# hi".data(using: .utf8)?.write(to: plainFile)
        defer { try? FileManager.default.removeItem(at: plainFile) }
        XCTAssertNil(try IAPresenterImporter.document(from: plainFile))
    }

    func testRoundTripExport() throws {
        var doc = DocumentFile(title: "round", markdown: "# A\n\n\n# B")
        doc.media.append(MediaAttachment(
            fileName: "pic.png", mime: "image/png",
            data: Data(base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
            )!
        ))
        doc.markdown += "\n\n![pic](\(doc.media[0].markdownRef))"

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("round-\(UUID().uuidString).iapresenter")
        defer { try? FileManager.default.removeItem(at: outURL) }

        try IAPresenterImporter.write(doc, to: outURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.appendingPathComponent("text.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.appendingPathComponent("info.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.appendingPathComponent("assets/pic.png").path))

        // Round-trip: re-importing must recover the media.
        let reimported = try XCTUnwrap(IAPresenterImporter.document(from: outURL))
        XCTAssertEqual(reimported.media.count, 1)
        XCTAssertTrue(reimported.markdown.contains("media://"))
    }

    func testIAParserSemantics() throws {
        let slide = MarkdownParser.parse("### 列一\n\t文字甲\n\n### 列二\n\t文字乙")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 2)
        XCTAssertEqual(content.layout, .columns, "multiple heading+text pairs form columns")

        let inline = MarkdownParser.parseInline("~~删除~~ 与 ==高亮==")
        XCTAssertEqual(inline.plainText, "删除 与 高亮", "markers must be stripped")
    }

    // MARK: iA layouts semantics

    func testTabbedTextBecomesKickerAboveTitle() throws {
        let slide = MarkdownParser.parse("\t小标题 Kicker\n\n# 主标题")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 2)
        XCTAssertEqual(content.kicker?.plainText, "小标题 Kicker")
        XCTAssertEqual(content.headline?.plainText, "主标题")
    }

    func testTitleSlideKickerAndTabbedSubtitle() throws {
        let slide = MarkdownParser.parse("\tFast and Focused\n\n# Main Title\n\n\tSubtitle line\n\n开场白")
        let content = ContentResolver.resolve(slide: slide, index: 0, total: 2)
        XCTAssertEqual(content.title?.plainText, "Main Title")
        XCTAssertEqual(content.kicker?.plainText, "Fast and Focused")
        XCTAssertEqual(content.subtitle?.plainText, "Subtitle line")
    }

    func testBackgroundImageIsExcludedFromLayout() throws {
        let slide = MarkdownParser.parse("# 标题\n\n![bg](media://x)\nbackground: true")
        let content = ContentResolver.resolve(slide: slide, index: 1, total: 2)
        XCTAssertNotEqual(content.layout, .split, "background image must not trigger split layout")
        XCTAssertEqual(content.layout, .statement)
        XCTAssertTrue(content.onSlide.contains { $0.isBackgroundMedia })
    }

    func testLayoutOverrideDisplayNames() {
        XCTAssertEqual(SlideLayoutKind.allCases.count, 9)
        XCTAssertFalse(SlideLayoutKind.statement.displayName.isEmpty)
    }

    func testZippedIABundleImports() throws {
        try makeBundle(text: "# 标题\n\n\t可见文字\n\n/assets/pic.png\n\n备注")
        // Zip the bundle the way Finder / iA exports it.
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zip-\(UUID().uuidString).iapresenter")
        defer { try? FileManager.default.removeItem(at: zipURL) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", bundleURL.path, zipURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let doc = try XCTUnwrap(IAPresenterImporter.document(from: zipURL))
        XCTAssertEqual(doc.media.count, 1, "assets inside the zip must be imported")
        let deck = Deck(text: doc.markdown)
        XCTAssertEqual(deck.contents.first?.title?.plainText, "标题")
    }
}
