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

    private func render(
        themeId: String,
        slideIndex: Int,
        mode: ColorMode = .light,
        size: CGSize = CGSize(width: 800, height: 450)
    ) -> NSBitmapImageRep? {
        let state = AppState()
        state.settings.themeId = themeId
        state.settings.colorMode = mode
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
        XCTAssertEqual(ProgressColorEngine.stageName(at: 0), "Blue")
        XCTAssertEqual(ProgressColorEngine.stageName(at: 1), "Gold")
        XCTAssertGreaterThan(start.blueComponent, start.redComponent, "cold start is systemBlue")
        XCTAssertGreaterThan(end.redComponent, end.blueComponent, "afterglow is systemYellow")
        XCTAssertGreaterThan(end.greenComponent, 0.5)
    }

    /// The default Glass theme: deep ink sinking into a system hue —
    /// a premium gradient, not a flat color.
    func testGlassThemePremiumGradient() throws {
        guard let rep = render(themeId: "glass", slideIndex: 0, mode: .dark) else {
            return XCTFail("render failed")
        }
        let top = pixel(rep, rep.pixelsWide / 2, 6)!
        let bottom = pixel(rep, rep.pixelsWide / 2, rep.pixelsHigh - 6)!
        // Top is deep ink (dark), bottom sinks into systemBlue (blue > red).
        XCTAssertLessThan(top.r + top.g + top.b, 0.6, "top should be deep ink")
        XCTAssertGreaterThan(bottom.b, bottom.r, "bottom should flow into a blue system hue")
        XCTAssertGreaterThan(distance(top, bottom), 0.2, "must be a real gradient")
        // White headline pixels.
        XCTAssertGreaterThan(whitePixelCount(rep), 40, "headline should render white")
    }

    /// Glass light mode must carry REAL hue — airy periwinkle pastels,
    /// not washed-out grey ("light 颜色全是灰色" regression test).
    func testGlassThemeLightModeIsColorful() throws {
        guard let rep = render(themeId: "glass", slideIndex: 0, mode: .light) else {
            return XCTFail("render failed")
        }
        let top = pixel(rep, rep.pixelsWide / 2, 6)!
        let bottom = pixel(rep, rep.pixelsWide / 2, rep.pixelsHigh - 6)!
        // Bright but with a clear blue bias: blue clearly beats red.
        XCTAssertGreaterThan(top.r + top.g + top.b, 2.2, "light mode should be airy and bright")
        XCTAssertGreaterThan(top.b - top.r, 0.05, "periwinkle should be blue, not grey")
        XCTAssertGreaterThan(bottom.b - bottom.r, 0.12, "systemBlue end should stay vivid")
        XCTAssertGreaterThan(distance(top, bottom), 0.25, "must be a real pastel gradient")
    }

    /// Regression test for "第二页开始都是小字": statement headlines must
    /// carry the fitted display size, not the default body font.
    func testStatementHeadlineRendersLarge() throws {
        guard let rep = render(
            themeId: "glass", slideIndex: 1, mode: .dark,
            size: CGSize(width: 1280, height: 720)
        ) else {
            return XCTFail("render failed")
        }
        // A fitted ~140pt white headline covers thousands of sample pixels;
        // the old bug (default 13pt font) would cover only a few hundred.
        XCTAssertGreaterThan(
            whitePixelCount(rep), 1500,
            "headline should render at display size, not body size"
        )
    }

    /// The sample deck's table slide (「数据一目了然」) must render its
    /// table with real content — headline + table rows on a gradient.
    func testTableSlideRenders() throws {
        let state = AppState()
        state.settings.themeId = "glass"
        state.settings.colorMode = .dark
        state.reparse()
        // Slide 5 (index 4, 「数据一目了然」) is the sample deck's table slide.
        guard state.deck.contents.indices.contains(4) else {
            return XCTFail("sample deck should have a table slide")
        }
        let content = state.deck.contents[4]
        XCTAssertEqual(content.layout, .table)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let image = ExportCoordinator.renderSlide(
            content: content,
            style: state.slideStyle(for: content),
            state: state,
            size: CGSize(width: 1280, height: 720)
        )
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
            return XCTFail("no bitmap")
        }
        // Headline + table text must be visible.
        XCTAssertGreaterThan(whitePixelCount(rep), 800, "table slide should show text")
        // The gradient backdrop must still be present (top vs bottom differ).
        if let top = pixel(rep, rep.pixelsWide / 2, 6),
           let bottom = pixel(rep, rep.pixelsWide / 2, rep.pixelsHigh - 6) {
            XCTAssertGreaterThan(distance(top, bottom), 0.05, "gradient backdrop missing")
        }
    }
}
