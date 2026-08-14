import XCTest
import AppKit
@testable import PresenterCore
@testable import Presenter

// MARK: - Offscreen render smoke test
//
// Renders the sample deck's slides to PNGs through the exact same
// SlideCanvas → NSHostingView pipeline the PDF/PNG export uses, and
// verifies each render is non-blank. The PNGs land in /tmp for
// visual inspection.

final class SlideRenderSmokeTests: XCTestCase {

    func testSampleDeckRendersNonBlankSlides() throws {
        let state = AppState()
        state.reparse()
        XCTAssertFalse(state.deck.contents.isEmpty, "sample deck should parse into slides")

        // Give SwiftUI a moment to settle layout.
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let size = CGSize(width: 1280, height: 720)
        for (i, content) in state.deck.contents.enumerated() {
            let style = state.slideStyle(for: content)
            let image = ExportCoordinator.renderSlide(
                content: content, style: style, state: state, size: size
            )
            XCTAssertEqual(image.size.width, size.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, size.height, accuracy: 0.5)

            guard
                let tiff = image.tiffRepresentation,
                let rep = NSBitmapImageRep(data: tiff)
            else {
                return XCTFail("slide \(i) produced no bitmap")
            }

            // Count distinct colors — a blank slide would have ~1.
            var distinct = Set<Int>()
            for y in stride(from: 0, to: rep.pixelsHigh, by: 6) {
                for x in stride(from: 0, to: rep.pixelsWide, by: 6) {
                    if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                        distinct.insert(
                            (Int(c.redComponent * 255) << 16)
                                | (Int(c.greenComponent * 255) << 8)
                                | Int(c.blueComponent * 255)
                        )
                    }
                }
            }
            XCTAssertGreaterThan(distinct.count, 8, "slide \(i) looks blank")

            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/presenter_slide_\(i).png"))
            }
        }
    }

    func testAllThemesRender() throws {
        let state = AppState()
        state.reparse()
        guard let content = state.deck.contents.first else {
            return XCTFail("no slides")
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let size = CGSize(width: 640, height: 360)

        for theme in Theme.all() {
            state.settings.themeId = theme.id
            let style = state.slideStyle(for: content)
            let image = ExportCoordinator.renderSlide(
                content: content, style: style, state: state, size: size
            )
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
                return XCTFail("theme \(theme.name) produced no bitmap")
            }
            XCTAssertGreaterThan(rep.pixelsWide, 0)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/presenter_theme_\(theme.id).png"))
            }
        }
    }

    /// Regression test for "点击演示无反应": the presenter window must
    /// actually become visible when presentation starts.
    func testPresenterWindowOpens() throws {
        let state = AppState()
        state.reparse()
        XCTAssertFalse(state.deck.contents.isEmpty, "sample deck should have slides")

        state.startPresentation()
        XCTAssertTrue(state.isPresenting)
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        XCTAssertTrue(
            PresenterWindowController.shared.isWindowVisible,
            "presenter window should be visible after startPresentation"
        )

        state.stopPresentation()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(state.isPresenting)
        XCTAssertFalse(PresenterWindowController.shared.isWindowVisible)
    }

    /// Region-aware arrow navigation: selecting in the thumbnails region
    /// moves between slides without touching the editor's caret.
    func testRegionNavigationMovesSlides() throws {
        let state = AppState()
        state.reparse()
        state.activeRegion = .thumbnails
        let before = state.currentSlide
        state.selectSlide(min(state.slideCount - 1, before + 1))
        XCTAssertEqual(state.currentSlide, before + 1)
        state.selectSlide(max(0, state.currentSlide - 1))
        XCTAssertEqual(state.currentSlide, before)
    }
}
