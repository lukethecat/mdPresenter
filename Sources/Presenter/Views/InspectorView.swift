import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PresenterCore

// MARK: - Inspector (⌥⌘I)
//
// Two tabs, like iA: Text (Speech vs. Text on Slide + Markdown tools)
// and Design (theme, colors, fonts, aspect ratio, header & footer).

struct InspectorView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0

    var body: some View {
        GlassPanel(cornerRadius: 16, tint: Color.black.opacity(state.currentSlideIsLight ? 0.32 : 0.14)) {
            VStack(spacing: 0) {
                SegmentedPicker(
                    options: [(0, "文本 Text"), (1, "设计 Design"), (2, "媒体 Media")],
                    selection: $tab
                )
                .padding(10)

                Divider().background(Color.white.opacity(0.07))

                ScrollView {
                    Group {
                        switch tab {
                        case 0: TextTab()
                        case 1: DesignTab()
                        default: MediaTab()
                        }
                    }
                    .padding(12)
                }
            }
        }
        .padding(10)
    }
}

// MARK: Media tab (iA's Media Manager)

private struct MediaTab: View {
    @EnvironmentObject var state: AppState
    @State private var editingID: String?
    @State private var editingName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("媒体库 Media Manager") {
                if state.media.isEmpty {
                    Text("还没有媒体。把图片拖进编辑器，或粘贴一张图片。")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x6E7279))
                } else {
                    VStack(spacing: 6) {
                        ForEach(state.media) { attachment in
                            HStack(spacing: 8) {
                                Image(systemName: attachment.isImage ? "photo" : (attachment.isVideo ? "play.rectangle" : "waveform"))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: 0xF5C518))
                                    .frame(width: 16)
                                if editingID == attachment.id {
                                    TextField("文件名", text: $editingName, onCommit: {
                                        state.renameMedia(id: attachment.id, to: editingName)
                                        editingID = nil
                                    })
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 11))
                                    .padding(4)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                                } else {
                                    Text(attachment.fileName)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: 0xD9D9D6))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(action: {
                                    state.insertMediaRef(id: attachment.id)
                                }) {
                                    Image(systemName: "plus.square.on.square")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: 0x9AA0A9))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("插入到当前幻灯片")
                                Button(action: {
                                    editingID = attachment.id
                                    editingName = attachment.fileName
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: 0x9AA0A9))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("重命名")
                                Button(action: { state.deleteMedia(id: attachment.id) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: 0xE53935))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("删除（同时移除引用）")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            section("YouTube") {
                Button(action: addYouTube) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.badge.plus")
                        Text("添加 YouTube 视频")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(GlassButtonStyle(accent: true, accentColor: Color(hex: 0xE53935)))
                Text("建议把 YouTube 视频放在空白幻灯片上，播放时显示面积最大。")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: 0x6E7279))
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            content()
        }
    }

    private func addYouTube() {
        let alert = NSAlert()
        alert.messageText = "添加 YouTube 视频"
        alert.informativeText = "粘贴 YouTube 链接："
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "https://www.youtube.com/watch?v=…"
        alert.accessoryView = field
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let url = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.isEmpty {
                state.addYouTubeLink(url)
            }
        }
    }
}

// MARK: Text tab

private struct TextTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let content = state.currentContent {
                section("Speech · 演讲备注") {
                    if content.notes.isEmpty {
                        Text("正文即备注。写下的每一段话，观众都看不到——只出现在你的提词器里。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: 0x6E7279))
                    } else {
                        NotesTextView(blocks: content.notes, size: 11.5)
                    }
                }

                section("Text on Slide · 幻灯片文本") {
                    if content.onSlide.isEmpty {
                        Text("标题、图片、表格会自动上屏；行首按 Tab ⇥ 也能强制文本上屏。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: 0x6E7279))
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(content.onSlide.enumerated()), id: \.offset) { _, block in
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: icon(for: block.kind))
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: 0xFFD600))
                                        .frame(width: 14)
                                    Text(block.plainText.isEmpty ? block.alt : block.plainText)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: 0xD9D9D6))
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("还没有幻灯片。写一个标题开始。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x6E7279))
            }

            Divider().background(Color(hex: 0x2A2C31))

            section("Markdown 格式") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    formatButton("bold", "B") { state.editorCommand.send(.wrapSelection(marker: "**", placeholder: "粗体")) }
                    formatButton("italic", "I") { state.editorCommand.send(.wrapSelection(marker: "*", placeholder: "斜体")) }
                    formatButton("chevron.left.slash.chevron.right", "`") { state.editorCommand.send(.wrapSelection(marker: "`", placeholder: "代码")) }
                    formatButton("textformat", "H1") { state.editorCommand.send(.prefixSelection(marker: "# ")) }
                    formatButton("textformat", "H2") { state.editorCommand.send(.prefixSelection(marker: "## ")) }
                    formatButton("textformat", "H3") { state.editorCommand.send(.prefixSelection(marker: "### ")) }
                    formatButton("list.bullet", "•") { state.editorCommand.send(.prefixSelection(marker: "- ")) }
                    formatButton("text.quote", "❝") { state.editorCommand.send(.prefixSelection(marker: "> ")) }
                    formatButton("tablecells", "▦") { insertTable() }
                    formatButton("photo.on.rectangle", "▣") { pickImage() }
                    formatButton("arrow.up.to.line", "⇥") { state.editorCommand.send(.prefixSelection(marker: "\t")) }
                    formatButton("rectangle.split.3x1", "+++") { insertSlideBreak() }
                }
            }
        }
    }

    private func icon(for kind: BlockKind) -> String {
        switch kind {
        case .heading: return "textformat.size"
        case .paragraph: return "text.alignleft"
        case .bulletList: return "list.bullet"
        case .orderedList: return "list.number"
        case .quote: return "text.quote"
        case .fencedCode: return "chevron.left.slash.chevron.right"
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .audio: return "waveform"
        case .table: return "tablecells"
        case .rule: return "minus"
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            content()
        }
    }

    private func formatButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 8.5, weight: .medium))
            }
            .foregroundColor(Color(hex: 0xB9BCC4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func insertTable() {
        let table = "\n| 列 1 | 列 2 |\n| --- | --- |\n| 内容 | 内容 |\n"
        // Insert at the end of the current slide.
        let ns = state.text as NSString
        var insertIndex = ns.length
        if state.deck.slides.indices.contains(state.currentSlide) {
            insertIndex = NSMaxRange(state.deck.slides[state.currentSlide].characterRange(in: ns))
        }
        let newText = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: table)
        state.text = newText
        state.editorCommand.send(.replaceText(newText))
    }

    private func insertSlideBreak() {
        let ns = state.text as NSString
        let location = min(state.selection.location, ns.length)
        let newText = ns.replacingCharacters(in: NSRange(location: location, length: 0), with: "\n\n---\n\n")
        state.text = newText
        state.editorCommand.send(.replaceText(newText))
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            DispatchQueue.main.async {
                state.attachMedia(
                    data: data,
                    fileName: url.lastPathComponent,
                    mime: MimeType.forExtension(url.pathExtension)
                )
            }
        }
    }
}

// MARK: Design tab

private struct DesignTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("主题 Theme") {
                Menu {
                    ForEach(Theme.all()) { theme in
                        Button(action: { state.settings.themeId = theme.id }) {
                            HStack {
                                themeDot(for: theme)
                                Text("\(theme.name) — \(theme.tagline)")
                                if theme.id == state.settings.themeId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    themeRow(state.theme)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            section("颜色 Colors") {
                SegmentedPicker(
                    options: [(ColorMode.light, "Light"), (ColorMode.dark, "Dark")],
                    selection: $state.settings.colorMode
                )
            }

            section("比例 Aspect") {
                Menu {
                    ForEach(AspectRatio.allCases) { aspect in
                        Button(action: { state.settings.aspect = aspect }) {
                            HStack {
                                Text(aspect.displayName)
                                if aspect == state.settings.aspect {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    menuLabel(state.settings.aspect.displayName)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }

            section("标题字体 Headline Font") {
                Menu {
                    Button(action: { state.settings.headlineFont = nil }) {
                        HStack {
                            Text("跟随主题")
                            if state.settings.headlineFont == nil { Image(systemName: "checkmark") }
                        }
                    }
                    ForEach(Typography.headlineChoices, id: \.key) { choice in
                        Button(action: { state.settings.headlineFont = choice.key }) {
                            HStack {
                                Text(choice.label).font(.custom(Typography.resolvedFamily(choice.key), size: 13))
                                if state.settings.headlineFont == choice.key { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    menuLabel(state.settings.headlineFont.map { Typography.resolvedFamily($0) } ?? "跟随主题")
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }

            section("强调色 Accent") {
                HStack {
                    ColorPicker(
                        "Accent",
                        selection: Binding(
                            get: {
                                if let hex = state.settings.accentHex,
                                   let c = NSColor(hexString: hex) {
                                    return Color(c)
                                }
                                return Color(state.theme.style(0, 1, state.settings.colorMode).accent)
                            },
                            set: { newColor in
                                state.settings.accentHex = NSColor(newColor).hexString
                            }
                        )
                    )
                    .labelsHidden()
                    if state.settings.accentHex != nil {
                        Button(action: { state.settings.accentHex = nil }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: 0x9AA0A9))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("恢复主题默认")
                    }
                    Spacer()
                }
            }

            section("页眉 Header") {
                TextField("页眉文字（显示在每张幻灯片左上角）", text: $state.settings.headerText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11.5))
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
            }

            section("页脚 Footer") {
                TextField("页脚文字", text: $state.settings.footerText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11.5))
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                Toggle(isOn: $state.settings.showPageNumber) {
                    Text("显示页码").font(.system(size: 11.5)).foregroundColor(Color(hex: 0xB9BCC4))
                }
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            content()
        }
    }

    private func themeRow(_ theme: Theme) -> some View {
        HStack(spacing: 8) {
            themeDot(for: theme)
            VStack(alignment: .leading, spacing: 1) {
                Text(theme.name).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0xD9D9D6))
                Text(theme.tagline).font(.system(size: 10)).foregroundColor(Color(hex: 0x8A8F98))
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: 0x6E7279))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }

    @ViewBuilder
    private func themeDot(for theme: Theme) -> some View {
        let style = theme.style(0, 1, .light)
        if style.background.count >= 2 {
            LinearGradient(
                gradient: Gradient(colors: style.background.prefix(2).map { Color($0) }),
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.2), lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(style.background.first ?? .white))
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: 0xD9D9D6))
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: 0x6E7279))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
    }
}
