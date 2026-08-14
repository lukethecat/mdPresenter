import XCTest
@testable import PresenterCore

// MARK: - 解析器模糊测试
//
// 「举一反三」：随机组合 Markdown 标点与中英文，确保任何输入都
// 能在有界时间内终止（曾经出现过「|」行导致死循环追加空段落、
// 2.6GB 内存的故障）。

final class MarkdownParserFuzzTests: XCTestCase {

    func testRandomInputsAlwaysTerminate() {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789#-*_>|[](){}.:,!?`~^= \t\\\n汉字句子，。！")
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<3000 {
            let length = Int.random(in: 0...60, using: &generator)
            let input = String((0..<length).map { _ in chars.randomElement(using: &generator)! })
            let blocks = MarkdownParser.parseBlocks(input)
            // 有界性断言：任何输入产出的块数必须远小于行数上限。
            XCTAssertLessThan(
                blocks.count, 2000,
                "parser must terminate with bounded blocks for input: \(input.debugDescription)"
            )
        }
    }

    func testMarkdownPunctuationLinesAlwaysTerminate() {
        let lines = [
            "|", "| |", "| a | b", "| --- | --- |", "||", "|>", "#", "#foo", "##", "### foo",
            ">", ">>", "> >", "-", "- ", "* ", "+ ", "1.", "1. ", "12. abc", "---", "___", "***",
            "```", "```swift", "~~~", "~", "~~x~~", "==", "==", "[", "[]", "[x]", "[^x]", "[x]: y",
            "![", "![]()", "![](x)", "<img>", "<img src=\"a.png\">", "$$x$$", "\\[x\\]", "\\", "  ",
            "\t", "\t- x", "\t1. x", "\t> q", ": def", "x~z", "100m^2", "10$", "$x$", "a.png",
            "/assets/a.png", "https://e.com/a.png?w=1#f", "media://abc", ":", "::", "\n\n\n",
        ]
        for line in lines {
            let blocks = MarkdownParser.parseBlocks(line)
            XCTAssertLessThan(blocks.count, 100, "must terminate for line: \(line.debugDescription)")
        }
    }
}
