import XCTest
import AppKit
import SwiftUI
@testable import PresenterCore
@testable import Presenter

// MARK: - 可用性回归：空白文档打字（用户报告的死机场景）与边界路径
//
// 复现方式：挂载完整的 MainView（真实 NSTextView + 面板 + 流体背景），
// 模拟「新建空白文稿 → 逐字输入」的完整事件链（textDidChange），
// 再渲染当前幻灯片，覆盖从编辑器到渲染器的全链路。

final class BlankDocumentTypingTests: XCTestCase {

    private func makeHost(state: AppState) -> (NSHostingView<AnyView>, NSTextView) {
        let root = AnyView(MainView().environmentObject(state))
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        hosting.layoutSubtreeIfNeeded()

        func findTextView(_ v: NSView) -> NSTextView? {
            if let tv = v as? NSTextView { return tv }
            for sub in v.subviews {
                if let found = findTextView(sub) { return found }
            }
            return nil
        }
        guard let textView = findTextView(hosting) else {
            fatalError("editor text view not found in hosting tree")
        }
        return (hosting, textView)
    }

    /// 模拟真实打字：设置文本并触发 textDidChange 委托链。
    private func type(_ text: String, into textView: NSTextView, state: AppState) {
        textView.string = text
        textView.delegate?.textDidChange?(
            Notification(name: NSText.didChangeNotification, object: textView)
        )
        // 让防抖解析与 SwiftUI 布局完成。
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    }

    func testBlankDocumentTypingSingleSentence() throws {
        let state = AppState()
        state.newDocument(blank: true)
        let (hosting, textView) = makeHost(state: state)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        // 逐句输入（先 ASCII 再中文，模拟真实打字过程）。
        type("hello", into: textView, state: state)
        type("hello world", into: textView, state: state)
        type("一句话", into: textView, state: state)
        type("一句话就够了", into: textView, state: state)

        XCTAssertEqual(state.slideCount, 1)
        XCTAssertTrue(state.deck.contents[0].notesPlain.contains("一句话就够了"))
        XCTAssertEqual(state.currentSlide, 0)

        // 渲染预览，覆盖 SlideCanvas 全链路。
        if let content = state.currentContent {
            _ = ExportCoordinator.renderSlide(
                content: content,
                style: state.slideStyle(for: content),
                state: state,
                size: CGSize(width: 800, height: 450)
            )
        }
        _ = hosting // 保持引用，防止提前释放。
    }

    func testBlankDocumentTypingBuildsSlides() throws {
        let state = AppState()
        state.newDocument(blank: true)
        let (_, textView) = makeHost(state: state)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        // 写出两张幻灯片（标题 + 分隔 + 备注）。
        type("# 第一页\n\n备注一", into: textView, state: state)
        type("# 第一页\n\n备注一\n\n---\n\n# 第二页\n\n备注二", into: textView, state: state)

        XCTAssertEqual(state.slideCount, 2)
        // 第一张是标题页：标题走 `title`，`headline` 按设计为 nil。
        XCTAssertEqual(state.deck.contents[0].title?.plainText, "第一页")
        XCTAssertEqual(state.deck.contents[1].headline?.plainText, "第二页")
    }

    /// 回归：空白文档第一句就按 Tab（首行缩进）时，Tab 不能被剥掉——
    /// 这句话必须上屏，而不是掉进备注。
    func testFirstLineTabbedTextStaysVisible() throws {
        let state = AppState()
        state.newDocument(blank: true)
        let (_, textView) = makeHost(state: state)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        type("\t第一句就上屏", into: textView, state: state)
        XCTAssertEqual(state.slideCount, 1)
        XCTAssertTrue(
            state.deck.contents[0].onSlide.contains { $0.isTabbedOnSlide },
            "first-line tab must survive slide splitting"
        )
        XCTAssertFalse(state.deck.contents[0].notesPlain.contains("第一句就上屏"))
    }

    func testDeleteAllTextReturnsToEmptyState() throws {
        let state = AppState()
        state.newDocument(blank: true)
        let (_, textView) = makeHost(state: state)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        type("写点什么", into: textView, state: state)
        type("", into: textView, state: state) // 全选删除

        XCTAssertEqual(state.slideCount, 0)
        XCTAssertNil(state.currentContent)
        // 空文档下切换主题与画幅也必须安全。
        state.settings.themeId = "dunhuang"
        state.settings.aspect = .mobile916
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(state.slideCount, 0)
    }

    func testTabbedTextAndMediaInBlankDocument() throws {
        let state = AppState()
        state.newDocument(blank: true)
        let (_, textView) = makeHost(state: state)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        type("\t这句话上屏", into: textView, state: state)
        XCTAssertTrue(state.deck.contents[0].onSlide.contains { $0.isTabbedOnSlide })

        // 粘贴图片（模拟 ⌘V 图片路径）。
        state.attachMedia(
            data: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")!,
            fileName: "tiny.png",
            mime: "image/png"
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(state.media.count, 1)
        if let content = state.currentContent {
            _ = ExportCoordinator.renderSlide(
                content: content,
                style: state.slideStyle(for: content),
                state: state,
                size: CGSize(width: 800, height: 450)
            )
        }
    }

    func testCJKTypingWithEveryTheme() throws {
        for themeId in Theme.all().map({ $0.id }) {
            let state = AppState()
            state.newDocument(blank: true)
            state.settings.themeId = themeId
            let (_, textView) = makeHost(state: state)
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))

            type("# 标题\n\n\t上屏文本\n\n**加粗备注**", into: textView, state: state)
            XCTAssertEqual(state.slideCount, 1, "theme \(themeId)")
            if let content = state.currentContent {
                _ = ExportCoordinator.renderSlide(
                    content: content,
                    style: state.slideStyle(for: content),
                    state: state,
                    size: CGSize(width: 640, height: 360)
                )
            }
        }
    }
}
