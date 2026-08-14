import XCTest
@testable import PresenterCore

final class SlideSplitterTests: XCTestCase {

    func testThreeReturnsCreateNewSlide() {
        let text = "First\n\n\nSecond"
        let slides = SlideSplitter.split(text)
        XCTAssertEqual(slides.count, 2)
        XCTAssertEqual(slides[0].source, "First")
        XCTAssertEqual(slides[1].source, "Second")
    }

    func testTripleDashCreatesNewSlide() {
        let text = "Slide one\n\n---\n\nSlide two"
        let slides = SlideSplitter.split(text)
        XCTAssertEqual(slides.count, 2)
        XCTAssertEqual(slides[0].source, "Slide one")
        XCTAssertEqual(slides[1].source, "Slide two")
    }

    func testSingleBlankLineDoesNotSplit() {
        let text = "Line one\n\nLine two"
        let slides = SlideSplitter.split(text)
        XCTAssertEqual(slides.count, 1)
        XCTAssertTrue(slides[0].source.contains("Line two"))
    }

    func testDeletingSeparatorMergesSlides() {
        let split = SlideSplitter.split("A\n\n\nB")
        XCTAssertEqual(split.count, 2)
        // Removing the separator = the two slides' text back to back.
        let merged = split.map { $0.source }.joined(separator: "\n")
        XCTAssertEqual(SlideSplitter.split(merged).count, 1)
    }

    func testWindowsLineEndings() {
        let text = "A\r\n\r\n\r\nB"
        XCTAssertEqual(SlideSplitter.split(text).count, 2)
    }

    func testEmptySlidesAreDropped() {
        let text = "# One\n\n\n\n\n\n# Two"
        let slides = SlideSplitter.split(text)
        XCTAssertEqual(slides.count, 2)
    }

    func testLineMappingAndCharacterRange() {
        let text = "# First\nbody\n\n\n# Second\nbody2"
        let slides = SlideSplitter.split(text)
        XCTAssertEqual(slides.count, 2)
        XCTAssertEqual(slides[1].startLine, 4)
        let ns = text as NSString
        let range = slides[1].characterRange(in: ns)
        XCTAssertEqual(ns.substring(with: range), "# Second\nbody2")
        XCTAssertEqual(SlideSplitter.slideIndex(at: 0, in: slides, text: ns), 0)
        XCTAssertEqual(SlideSplitter.slideIndex(at: ns.length - 1, in: slides, text: ns), 1)
    }

    func testCJKTextSplits() {
        let text = "第一张幻灯片\n\n\n第二张幻灯片"
        XCTAssertEqual(SlideSplitter.split(text).count, 2)
    }
}
