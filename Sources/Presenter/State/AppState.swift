import AppKit
import Combine
import Foundation
import SwiftUI
import PresenterCore

// MARK: - Editor commands (SwiftUI → NSTextView)

public enum EditorCommand {
    case replaceText(String)
    case wrapSelection(marker: String, placeholder: String)
    case prefixSelection(marker: String)
    case scrollToSlide(Int)
    case focusEditor
}

// MARK: - App state
//
// The single source of truth. Text flows from the editor into here,
// gets debounced through the parse pipeline (split → parse → resolve),
// and every panel renders from the resulting Deck.

final class AppState: ObservableObject {

    /// The live app instance (menus, key monitor and windows share it).
    static let shared = AppState()

    /// Which UI region the user last interacted with — arrow keys follow it.
    enum FocusRegion {
        case editor
        case thumbnails
        case preview
    }

    @Published var text: String = "" {
        didSet { if text != oldValue { scheduleParse() } }
    }
    @Published var deck = Deck()
    @Published var settings = DeckSettings()
    @Published var media: [MediaAttachment] = []
    @Published var documentTitle = "Untitled"
    @Published var documentURL: URL?

    @Published var currentSlide = 0
    @Published var activeRegion: FocusRegion = .editor
    @Published var showThumbnails = true
    @Published var showPreview = true
    @Published var showInspector = true
    @Published var focusMode = false
    @Published var turboBanner = false
    @Published var previewDevice: PreviewDevice = .desktop
    @Published var selection = NSRange(location: 0, length: 0)

    @Published var isPresenting = false
    @Published var presenterIndex = 0
    @Published var presenterPanelVisible = false

    enum PreviewDevice: String, CaseIterable {
        case desktop
        case mobile
        var label: String { self == .desktop ? "Desktop" : "Mobile" }
    }

    let editorCommand = PassthroughSubject<EditorCommand, Never>()

    private var cancellables = Set<AnyCancellable>()
    private var parseTask: DispatchWorkItem?

    init() {
        text = SampleDeck.instantSlides
        settings.themeId = "glass"
        documentTitle = SampleDeck.instantSlidesTitle

        $text
            .removeDuplicates()
            .sink { [weak self] _ in self?.scheduleParse() }
            .store(in: &cancellables)

        $focusMode
            .sink { [weak self] _ in
                self?.editorCommand.send(.focusEditor)
            }
            .store(in: &cancellables)
    }

    // MARK: Parse pipeline

    private func scheduleParse() {
        parseTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.reparse()
        }
        parseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: task)
    }

    func reparse() {
        let previousCount = deck.slides.count
        deck = Deck(text: text)
        // Layout overrides are keyed by slide index — reset on structure change.
        if deck.slides.count != previousCount {
            layoutOverrides = [:]
        }
        if deck.contents.isEmpty {
            currentSlide = 0
        } else if currentSlide >= deck.contents.count {
            currentSlide = deck.contents.count - 1
        }
        if documentTitle == "Untitled" || documentTitle.isEmpty {
            if let title = deck.contents.first?.title {
                documentTitle = title.plainText
            }
        }
        if deck.slides.isEmpty { turboBanner = false }
    }

    // MARK: Derived

    var slideCount: Int { deck.slides.count }
    var wordCount: Int {
        text.split { $0.isWhitespace }.count
    }
    var totalEstimateMinutes: Double {
        SpeechTimer.estimatedMinutes(slides: deck.contents)
    }
    var totalEstimateLabel: String {
        SpeechTimer.label(minutes: totalEstimateMinutes)
    }

    var theme: Theme { Theme.theme(id: settings.themeId) }

    var currentContent: SlideContent? {
        guard deck.contents.indices.contains(currentSlide) else { return nil }
        return deck.contents[currentSlide]
    }

    func slideStyle(for content: SlideContent) -> SlideStyle {
        var style = theme.style(content.index, content.total, settings.colorMode)
        if let family = settings.headlineFont {
            style.headlineFamily = Typography.resolvedFamily(family)
        }
        if let hex = settings.accentHex, let color = NSColor(hexString: hex) {
            style.accent = color
        }
        return style
    }

    /// Whether the current slide's pigment is light — the glass scrims
    /// darken adaptively on light slides (瓷白、琉璃金…) and stay clear
    /// on dark ones (石青、宫墙红…), keeping chrome text readable.
    var currentSlideIsLight: Bool {
        guard let content = currentContent else { return false }
        let style = slideStyle(for: content)
        return !(style.background.first?.isDark ?? true)
    }

    func media(for block: Block) -> MediaAttachment? {
        guard let id = block.mediaId else { return nil }
        return media.first { $0.id == id }
    }

    // MARK: Slide navigation

    /// Select a slide without stealing keyboard focus — the region the user
    /// last clicked keeps the arrow keys (see the key monitor in AppDelegate).
    func selectSlide(_ index: Int) {
        guard deck.contents.indices.contains(index) else { return }
        currentSlide = index
        editorCommand.send(.scrollToSlide(index))
    }

    func setCursorSlide(_ index: Int) {
        guard deck.contents.indices.contains(index), index != currentSlide else { return }
        currentSlide = index
    }

    // MARK: Document lifecycle

    func newDocument(blank: Bool = false) {
        text = blank ? "" : SampleDeck.instantSlides
        documentTitle = blank ? "Untitled" : SampleDeck.instantSlidesTitle
        documentURL = nil
        media = []
        currentSlide = 0
        reparse()
        editorCommand.send(.replaceText(text))
        editorCommand.send(.focusEditor)
    }

    func load(document: DocumentFile, url: URL?) {
        text = document.markdown
        settings = document.settings
        media = document.media
        documentTitle = document.title
        documentURL = url
        currentSlide = 0
        reparse()
        editorCommand.send(.replaceText(text))
        editorCommand.send(.focusEditor)
    }

    func currentDocument() -> DocumentFile {
        DocumentFile(title: documentTitle, markdown: text, settings: settings, media: media)
    }

    // MARK: Media (drag & drop / paste)

    func attachMedia(data: Data, fileName: String, mime: String) {
        let attachment = MediaAttachment(fileName: fileName, mime: mime, data: data)
        media.append(attachment)
        let line = "\n![\(fileName.replacingOccurrences(of: "]", with: ""))](\(attachment.markdownRef))\n"
        let ns = text as NSString
        var insertIndex = ns.length
        if deck.slides.indices.contains(currentSlide) {
            let range = deck.slides[currentSlide].characterRange(in: ns)
            insertIndex = NSMaxRange(range)
        }
        let newText = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: line)
        text = newText
        editorCommand.send(.replaceText(newText))
        editorCommand.send(.scrollToSlide(currentSlide))
    }

    /// Insert an existing media reference at the end of the current slide.
    func insertMediaRef(id: String) {
        guard let attachment = media.first(where: { $0.id == id }) else { return }
        let line = "\n![\(attachment.fileName)](\(attachment.markdownRef))\n"
        let ns = text as NSString
        var insertIndex = ns.length
        if deck.slides.indices.contains(currentSlide) {
            insertIndex = NSMaxRange(deck.slides[currentSlide].characterRange(in: ns))
        }
        let newText = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: line)
        text = newText
        editorCommand.send(.replaceText(newText))
        editorCommand.send(.scrollToSlide(currentSlide))
    }

    /// Media Manager: rename an attachment (keep the extension!).
    func renameMedia(id: String, to newName: String) {
        guard let idx = media.firstIndex(where: { $0.id == id }) else { return }
        media[idx].fileName = newName
    }

    /// Media Manager: delete an attachment and its markdown references.
    func deleteMedia(id: String) {
        guard let attachment = media.first(where: { $0.id == id }) else { return }
        media.removeAll { $0.id == id }
        // Strip image lines referencing this attachment.
        // 直接用字符串替换（避免 String 正则引擎，见 MarkdownParser 注释）。
        let ref = attachment.markdownRef
        var stripped = text
        while let range = stripped.range(of: "![") {
            guard let close = stripped[range.upperBound...].firstIndex(of: "]") else { break }
            let after = stripped.index(after: close)
            if after < stripped.endIndex, stripped[after] == "(",
               let paren = stripped[after...].firstIndex(of: ")") {
                let inner = stripped[stripped.index(after: after)..<paren]
                if inner == ref {
                    var lineEnd = stripped.index(after: paren)
                    if lineEnd < stripped.endIndex, stripped[lineEnd] == "\n" {
                        lineEnd = stripped.index(after: lineEnd)
                    }
                    stripped.removeSubrange(range.lowerBound..<lineEnd)
                    continue
                }
            }
            break
        }
        if stripped != text {
            text = stripped
            editorCommand.send(.replaceText(stripped))
        }
    }

    /// Media Manager: add a YouTube link as a video block.
    func addYouTubeLink(_ url: String) {
        let line = "\n![🎬 YouTube](\(url))\n"
        let ns = text as NSString
        var insertIndex = ns.length
        if deck.slides.indices.contains(currentSlide) {
            insertIndex = NSMaxRange(deck.slides[currentSlide].characterRange(in: ns))
        }
        let newText = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: line)
        text = newText
        editorCommand.send(.replaceText(newText))
        editorCommand.send(.scrollToSlide(currentSlide))
    }

    // MARK: Layout overrides (iA's "+" layout picker)

    @Published var layoutOverrides: [Int: SlideLayoutKind] = [:]

    func layoutOverride(for index: Int) -> SlideLayoutKind? {
        layoutOverrides[index]
    }

    func setLayoutOverride(_ layout: SlideLayoutKind?, for index: Int) {
        if let layout = layout {
            layoutOverrides[index] = layout
        } else {
            layoutOverrides.removeValue(forKey: index)
        }
    }

    // MARK: TurboStart

    func applyTurboStart() {
        switch TurboStart.convert(text) {
        case .converted(let md):
            text = md
            editorCommand.send(.replaceText(md))
            reparse()
        case .untouched:
            break
        }
        turboBanner = false
    }

    // MARK: Presentation

    func startPresentation() {
        guard !deck.contents.isEmpty else {
            // Never fail silently: explain why there is nothing to present.
            let alert = NSAlert()
            alert.messageText = "还没有幻灯片"
            alert.informativeText = "先写下一个标题（`# 标题`），或导入一段文本，然后再上台。"
            alert.alertStyle = .informational
            alert.runModal()
            return
        }
        presenterIndex = currentSlide
        isPresenting = true
        PresenterWindowController.shared.present(state: self)
    }

    func stopPresentation() {
        isPresenting = false
        presenterPanelVisible = false
        PresenterWindowController.shared.close()
    }

    func presenterNext() {
        presenterIndex = min(presenterIndex + 1, max(0, deck.contents.count - 1))
    }

    func presenterPrevious() {
        presenterIndex = max(presenterIndex - 1, 0)
    }
}

// MARK: - Sample deck ("Instant Slides")

enum SampleDeck {
    static let instantSlidesTitle = "欢迎使用 Presenter"

    static let instantSlides = """
    # 欢迎使用 Presenter

    ## 把故事讲给他们听

    这是你的第一份演示文稿。**用粗体标记的句子**会以高亮提示出现在演讲者视图的提词器里。观众看不到这些文字——它们只属于你。

    ---

    # 写作，就是全部

    用 Markdown 写作，Presenter 负责设计。连续按三次回车，或者输入 `---`，就会创建一张新幻灯片。

    正文是演讲备注，标题才会上屏幕。试试把光标往下移动——光标颜色会随着演示进度，从 Blue 渐渐变成 Gold。

    ---

    # 内容与展示分离

    \t行首按 Tab ⇥，就能让这句话出现在幻灯片上。

    这句话是备注，只有你自己看得到。演讲时它会出现在提词器里，像一张安全网。

    ---

    # 自动设计，玻璃质感

    设计引擎会分析内容，自动挑选布局。默认的 Glass 主题用深墨与系统色渐变，逐页在 Blue、Indigo、Teal、Purple 间流转。

    窗口背景的流体会采样你桌面壁纸的颜色——应用与它的环境同呼吸。在右侧 Inspector 的 Design 标签里可以切换主题、明暗模式与画面比例。

    ---

    # 数据一目了然

    | 指标 | 数值 |
    | --- | --- |
    | 幻灯片 | 5 |
    | 演讲时长 | ≈ 1 min |
    | 设计决策 | 0 |

    表格、图片、代码块会自动上屏；拖一张图片进来试试。

    ---

    # 准备好了就上台

    按 ⌥⌘P 打开演讲者视图。左侧是观众看到的画面，右侧是你的提词器。

    **深呼吸，开始吧。**
    """
}
