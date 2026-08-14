import XCTest
import AppKit
@testable import PresenterCore
@testable import Presenter

// MARK: - Pixel-level design verification
//
// The harness model cannot view images, so we verify the visual design
// objectively: traditional pigment backgrounds, celadon gradients, and
// rendered headline pixels.

final class DesignVerificationTests: XCTestCase {

    private func render(themeId: String, slideIndex: Int, size: CGSize = CGSize(width: 800, height: 450)) -> NSBitmapImageRep? {
        let state = AppState()
        state.settings.themeId = themeId
        state.reparse()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        guard state.deck.contents.indices.contains(slideIndex) else { return nil }
        let content = state.deck.contents[slideIndex]
        let style = state.slideStyle(for: content)
        let image = ExportCoordinator.renderSlide(
            content: content, style: style, state: state, size: size
        )
        guard let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }

    private func pixel(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return nil }
        return (c.redComponent, c.greenComponent, c.blueComponent)
    }

    private func distance(_ a: (r: CGFloat, g: CGFloat, b: CGFloat), _ b: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b)
    }

    private func whitePixelCount(_ rep: NSBitmapImageRep) -> Int {
        var count = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 4) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 4) {
                if let p = pixel(rep, x, y), p.r > 0.9, p.g > 0.9, p.b > 0.9 {
                    count += 1
                }
            }
        }
        return count
    }

    func testDunhuangMineralPigmentsCycle() throws {
        guard let first = render(themeId: "dunhuang", slideIndex: 0),
              let second = render(themeId: "dunhuang", slideIndex: 1) else {
            return XCTFail("render failed")
        }
        let bg1 = pixel(first, 8, 8)!
        let bg2 = pixel(second, 8, 8)!
        // 石青 azurite on slide 0, 石绿 malachite on slide 1.
        XCTAssertLessThan(distance(bg1, (0x2E / 255.0, 0x5F / 255.0, 0x88 / 255.0)), 0.2, "slide 0 should be azurite 石青")
        XCTAssertLessThan(distance(bg2, (0x3E / 255.0, 0x8E / 255.0, 0x7E / 255.0)), 0.2, "slide 1 should be malachite 石绿")
        XCTAssertGreaterThan(whitePixelCount(first), 60, "headline text should render white")
    }

    func testRuKilnCeladonGradient() throws {
        guard let rep = render(themeId: "ru", slideIndex: 0) else {
            return XCTFail("render failed")
        }
        let top = pixel(rep, rep.pixelsWide / 2, 6)!
        let bottom = pixel(rep, rep.pixelsWide / 2, rep.pixelsHigh - 6)!
        XCTAssertGreaterThan(distance(top, bottom), 0.10, "Ru kiln backgrounds must be top-to-bottom celadon gradients")
        // 雨过天青 — overall light and quiet.
        XCTAssertGreaterThan(top.r + top.g + top.b, 2.0, "light Ru kiln should be bright")
    }

    func testGugongAlternatesGoldAndRed() throws {
        guard let first = render(themeId: "gugong", slideIndex: 0),
              let second = render(themeId: "gugong", slideIndex: 1) else {
            return XCTFail("render failed")
        }
        let bg1 = pixel(first, 8, 8)!
        let bg2 = pixel(second, 8, 8)!
        XCTAssertLessThan(distance(bg1, (0xC9 / 255.0, 0xA0 / 255.0, 0x63 / 255.0)), 0.15, "slide 0 should be glazed gold 琉璃金")
        XCTAssertLessThan(distance(bg2, (0x9E / 255.0, 0x2A / 255.0, 0x22 / 255.0)), 0.15, "slide 1 should be wall red 宫墙红")
    }

    func testQinghuaAlternatesPorcelainAndCobalt() throws {
        guard let first = render(themeId: "qinghua", slideIndex: 0),
              let second = render(themeId: "qinghua", slideIndex: 1) else {
            return XCTFail("render failed")
        }
        let bg1 = pixel(first, 8, 8)!
        let bg2 = pixel(second, 8, 8)!
        XCTAssertGreaterThan(bg1.r + bg1.g + bg1.b, 2.8, "slide 0 should be porcelain white 瓷白")
        XCTAssertLessThan(distance(bg2, (0x1F / 255.0, 0x4E / 255.0, 0x8C / 255.0)), 0.15, "slide 1 should be cobalt blue 钴蓝")
    }

    func testJiangnanPastelBackground() throws {
        guard let rep = render(themeId: "jiangnan", slideIndex: 0) else {
            return XCTFail("render failed")
        }
        let bg = pixel(rep, 8, 8)!
        XCTAssertGreaterThan(bg.r, 0.8)
        XCTAssertGreaterThan(bg.g, 0.8)
        XCTAssertGreaterThan(bg.b, 0.85)
        XCTAssertLessThan(bg.r + bg.g + bg.b, 2.95, "pastel 月白, not pure white")
    }

    func testWuxingCoversAllFiveElements() throws {
        let names = ["青", "赤", "黄", "白", "黑"]
        var backgrounds: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        for i in 0..<5 {
            guard let rep = render(themeId: "wuxing", slideIndex: i) else {
                return XCTFail("render failed for slide \(i)")
            }
            backgrounds.append(pixel(rep, 8, 8)!)
        }
        // Every element background must differ from the previous one.
        for i in 1..<5 {
            XCTAssertGreaterThan(distance(backgrounds[i], backgrounds[i - 1]), 0.2, "\(names[i]) should differ from \(names[i - 1])")
        }
    }

    func testProgressColorsIndigoToGold() {
        let start = ProgressColorEngine.color(at: 0)
        let end = ProgressColorEngine.color(at: 1)
        XCTAssertEqual(ProgressColorEngine.stageName(at: 0), "靛青")
        XCTAssertEqual(ProgressColorEngine.stageName(at: 1), "鎏金")
        XCTAssertGreaterThan(start.blueComponent, start.redComponent, "cold start is indigo 靛青")
        XCTAssertGreaterThan(end.redComponent, end.blueComponent, "afterglow is gold 鎏金")
        XCTAssertGreaterThan(end.greenComponent, 0.5)
    }
}
