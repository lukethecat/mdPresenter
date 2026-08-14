import XCTest
@testable import PresenterCore

final class TurboStartTests: XCTestCase {

    func testAlreadySeparatedTextIsUntouched() {
        let text = "# A\n\n\n# B"
        guard case .untouched = TurboStart.convert(text) else {
            return XCTFail("should be untouched")
        }
    }

    func testProseBecomesSlides() {
        let text = "First idea\nSecond idea that is longer and contains more words"
        guard case .converted(let md) = TurboStart.convert(text) else {
            return XCTFail("should be converted")
        }
        let slides = SlideSplitter.split(md)
        XCTAssertEqual(slides.count, 2)
        XCTAssertTrue(slides[0].source.contains("# First idea"))
        XCTAssertTrue(slides[1].source.contains("# Second idea"))
    }

    func testLongParagraphFirstSentenceBecomesHeadline() {
        let text = "这是第一句话。这是第二句话，作为演讲备注保留下来。\n另一个段落。"
        guard case .converted(let md) = TurboStart.convert(text) else {
            return XCTFail("should be converted")
        }
        let slides = SlideSplitter.split(md)
        XCTAssertEqual(slides.count, 2)
        XCTAssertTrue(slides[0].source.contains("# 这是第一句话。"))
        XCTAssertTrue(slides[0].source.contains("这是第二句话"))
    }

    func testSingleParagraphUntouched() {
        guard case .untouched = TurboStart.convert("Only one paragraph") else {
            return XCTFail("should be untouched")
        }
    }
}

final class ProgressColorTests: XCTestCase {

    func testEndpoints() {
        let start = ProgressColorEngine.color(at: 0)
        let end = ProgressColorEngine.color(at: 1)
        XCTAssertGreaterThan(start.hexString.lowercased().dropFirst().first.map { _ in 0 } ?? 0, -1)
        // systemBlue start, systemYellow end.
        XCTAssertEqual(ProgressColorEngine.stageName(at: 0), "Blue")
        XCTAssertEqual(ProgressColorEngine.stageName(at: 1), "Gold")
        let (hStart, _, _) = start.hsb
        let (hEnd, _, _) = end.hsb
        XCTAssertLessThan(abs(hStart - 0.58), 0.25) // bluish hue
        XCTAssertLessThan(abs(hEnd - 0.12), 0.2)   // golden hue
    }

    func testClamped() {
        let below = ProgressColorEngine.color(at: -5)
        let above = ProgressColorEngine.color(at: 5)
        XCTAssertEqual(below.hexString, ProgressColorEngine.color(at: 0).hexString)
        XCTAssertEqual(above.hexString, ProgressColorEngine.color(at: 1).hexString)
    }
}

final class SpeechTimerTests: XCTestCase {

    func testLatinEstimate() {
        // 150 words ≈ 1 minute
        let words = Array(repeating: "word", count: 150).joined(separator: " ")
        let minutes = SpeechTimer.estimatedMinutes(notes: words)
        XCTAssertEqual(minutes, 1.0, accuracy: 0.05)
    }

    func testCJKEstimate() {
        // 240 chars ≈ 1 minute
        let chars = String(repeating: "字", count: 240)
        let minutes = SpeechTimer.estimatedMinutes(notes: chars)
        XCTAssertEqual(minutes, 1.0, accuracy: 0.1)
    }

    func testEmpty() {
        XCTAssertEqual(SpeechTimer.estimatedMinutes(notes: ""), 0)
    }
}

final class LayoutEngineTests: XCTestCase {

    func testFitFontSizeShrinksLongText() {
        let short = LayoutEngine.fitFontSize(
            text: "Hi", family: "Helvetica Neue", weight: .bold,
            maxSize: 100, minSize: 12, in: CGSize(width: 800, height: 400)
        )
        let long = LayoutEngine.fitFontSize(
            text: String(repeating: "Very long headline words ", count: 40),
            family: "Helvetica Neue", weight: .bold,
            maxSize: 100, minSize: 12, in: CGSize(width: 800, height: 400)
        )
        XCTAssertGreaterThan(short, long)
    }

    func testFittedMediaKeepsAspect() {
        let fitted = LayoutEngine.fittedMediaSize(mediaSize: CGSize(width: 4000, height: 3000), in: CGSize(width: 800, height: 800))
        XCTAssertEqual(fitted.width / fitted.height, 4.0 / 3.0, accuracy: 0.01)
        XCTAssertLessThanOrEqual(fitted.width, 800)
        XCTAssertLessThanOrEqual(fitted.height, 800)
    }
}

final class DocumentFileTests: XCTestCase {

    func testRoundTrip() throws {
        var doc = DocumentFile(title: "Test", markdown: "# Hi\n\n\n# There")
        doc.settings.themeId = "tokyo"
        doc.media.append(MediaAttachment(fileName: "cat.png", mime: "image/png", data: Data([0x89, 0x50])))
        let data = try doc.encoded()
        let decoded = try DocumentFile.decode(data)
        XCTAssertEqual(decoded.title, "Test")
        XCTAssertEqual(decoded.settings.themeId, "tokyo")
        XCTAssertEqual(decoded.media.count, 1)
        XCTAssertEqual(decoded.media[0].mime, "image/png")
    }

    func testMediaLookup() {
        let attachment = MediaAttachment(id: "fixed-id", fileName: "a.png", mime: "image/png", data: Data())
        var doc = DocumentFile(title: "T", markdown: "")
        doc.media = [attachment]
        var block = Block(kind: .image)
        block.mediaRef = "media://fixed-id"
        XCTAssertEqual(doc.media(for: block)?.fileName, "a.png")
    }
}
