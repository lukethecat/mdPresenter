import AppKit
import Combine
import SwiftUI
import PresenterCore

// MARK: - Presentation Mode (the teleprompter)
//
// ⌥⌘P opens a dedicated screen: the audience sees the slide, you see your
// notes on top of it. Two modes: Speaker Notes (default) and Thumbnails.
// The elapsed timer, the next-slide preview and the blue→gold progress
// color all follow iA's presentation mode.

struct PresenterView: View {
    @EnvironmentObject var state: AppState
    @State private var mode: PresenterMode = .notes
    @State private var elapsed: TimeInterval = 0
    @State private var startDate = Date()
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    enum PresenterMode {
        case notes
        case thumbnails
    }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width * 1.05
            let detectedAspect = portrait ? 9.0 / 16.0 : 16.0 / 9.0
            let slideAspect = state.settings.aspect.ratio ?? detectedAspect

            VStack(spacing: 0) {
                toolbar
                HStack(spacing: 0) {
                    stage(portrait: portrait, slideAspect: slideAspect)
                    sidePanel(width: min(440, geo.size.width * 0.34))
                }
                progressBar
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(startDate)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            SegmentedPicker(
                options: [(PresenterMode.notes, "备注"), (PresenterMode.thumbnails, "缩略图")],
                selection: $mode
            )
            .frame(width: 170)

            Spacer()

            if let content = currentContent {
                let color = ProgressColorEngine.color(at: content.progress)
                Circle().fill(Color(color)).frame(width: 8, height: 8)
                Text(stageName(ProgressColorEngine.stageName(at: content.progress)))
                    .foregroundColor(Color(color))
                Text("\(state.presenterIndex + 1) / \(max(1, state.deck.contents.count))")
                    .foregroundColor(Color(hex: 0xB9BCC4))
            }

            Button(action: { startDate = Date(); elapsed = 0 }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(clockString(elapsed))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(GlassButtonStyle())
            .help("点击重置计时器")

            Button(action: { state.stopPresentation() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.white)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(GlassButtonStyle(accent: true, accentColor: Color(hex: 0xE53935)))
            .help("停止演示 (⌥⌘P / Esc)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 0, tint: Color.black.opacity(0.45))
    }

    // MARK: Stage

    private func stage(portrait: Bool, slideAspect: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: 0x0B0C0E)
                if let content = currentContent {
                    let style = state.slideStyle(for: content)
                    let available = geo.size
                    let fitRatio = available.width / max(1, available.height)
                    let slideW: CGFloat = fitRatio > slideAspect
                        ? available.height * slideAspect
                        : available.width
                    let slideH: CGFloat = fitRatio > slideAspect
                        ? available.height
                        : available.width / slideAspect
                    SlideCanvas(
                        content: content,
                        style: style,
                        settings: state.settings,
                        media: state.media
                    )
                    .frame(width: slideW, height: slideH)
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 10)
                    .onTapGesture { state.presenterNext() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    // MARK: Side panel

    @ViewBuilder
    private func sidePanel(width: CGFloat) -> some View {
        GlassPanel(cornerRadius: 20, tint: Color.black.opacity(0.42)) {
            VStack(spacing: 0) {
                nextSlide(width: width)
                Divider().background(Color.white.opacity(0.08))
                if mode == .notes {
                    notesPanel
                } else {
                    thumbnailsPanel
                    Divider().background(Color.white.opacity(0.08))
                    notesStrip
                }
            }
        }
        .frame(width: width)
        .padding(12)
    }

    private func nextSlide(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "接下来 · Next")
            if state.deck.contents.indices.contains(state.presenterIndex + 1) {
                let content = state.deck.contents[state.presenterIndex + 1]
                SlideCanvas(
                    content: content,
                    style: state.slideStyle(for: content),
                    settings: state.settings,
                    media: state.media
                )
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(maxWidth: width * 0.9)
                Text(content.headline?.plainText ?? content.title?.plainText ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: 0x9AA0A9))
                    .lineLimit(1)
            } else {
                VStack {
                    Text("🎉")
                    Text("最后一页")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x8A8F98))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            }
        }
        .padding(16)
    }

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "提词器 · Teleprompter")
            if let content = currentContent, !content.notes.isEmpty {
                ScrollView {
                    NotesTextView(
                        blocks: content.notes,
                        size: 21,
                        dimColor: Color(hex: 0xE8E8EA),
                        promptColor: Color(hex: 0xFFD479)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 6)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 26, weight: .light))
                    Text("这张幻灯片没有备注")
                        .font(.system(size: 13))
                }
                .foregroundColor(Color(hex: 0x6E7279))
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(16)
    }

    private var thumbnailsPanel: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ForEach(state.deck.contents.indices, id: \.self) { index in
                    let content = state.deck.contents[index]
                    let isCurrent = index == state.presenterIndex
                    Button(action: { state.presenterIndex = index }) {
                        SlideCanvas(
                            content: content,
                            style: state.slideStyle(for: content),
                            settings: state.settings,
                            media: state.media
                        )
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isCurrent ? Color(ProgressColorEngine.color(at: content.progress)) : Color.white.opacity(0.08),
                                    lineWidth: isCurrent ? 2 : 1
                                )
                        )
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                                .padding(5),
                            alignment: .topLeading
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(14)
        }
    }

    private var notesStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "提词器 · Teleprompter")
            if let content = currentContent, !content.notes.isEmpty {
                ScrollView {
                    NotesTextView(blocks: content.notes, size: 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("这张幻灯片没有备注")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x6E7279))
            }
        }
        .padding(14)
        .frame(height: 170)
    }

    // MARK: Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = state.deck.contents.count > 1
                ? Double(state.presenterIndex) / Double(state.deck.contents.count - 1)
                : 1.0
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.06))
                Rectangle()
                    .fill(Color(ProgressColorEngine.color(at: progress)))
                    .frame(width: max(24, geo.size.width * CGFloat(progress)))
                    .animation(.easeOut(duration: 0.3))
            }
        }
        .frame(height: 5)
    }

    // MARK: Helpers

    private var currentContent: SlideContent? {
        guard state.deck.contents.indices.contains(state.presenterIndex) else { return nil }
        return state.deck.contents[state.presenterIndex]
    }

    private func clockString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func stageName(_ raw: String) -> String {
        switch raw {
        case "靛青": return "靛青 · 冷启动"
        case "黛紫": return "黛紫 · 预热"
        case "朱砂": return "朱砂 · 高潮"
        case "琥珀": return "琥珀 · 收尾"
        case "鎏金": return "鎏金 · 余韵"
        default: return raw
        }
    }
}

// MARK: - Presenter window (AppKit shell)

final class PresenterWindowController {
    static let shared = PresenterWindowController()

    private var window: NSWindow?
    private var keyMonitor: Any?
    private weak var state: AppState?

    func present(state: AppState) {
        self.state = state
        if window == nil {
            let screen = NSScreen.screens.first(where: { $0 != NSScreen.main }) ?? NSScreen.main
            let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

            let root = PresenterView().environmentObject(state)
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(
                contentRect: frame,
                styleMask: [.borderless, .resizable],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hosting
            win.backgroundColor = .black
            win.isOpaque = true
            win.hasShadow = false
            win.isReleasedWhenClosed = false
            win.title = "Presenter — 演讲者视图"
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window = win

            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, let state = self.state, state.isPresenting else { return event }
                switch event.keyCode {
                case 123: state.presenterPrevious(); return nil // ←
                case 124: state.presenterNext(); return nil     // →
                case 125: state.presenterNext(); return nil     // ↓
                case 126: state.presenterPrevious(); return nil // ↑
                case 49: state.presenterNext(); return nil      // space
                case 53: state.stopPresentation(); return nil   // esc
                case 15:
                    if event.charactersIgnoringModifiers == "r" { return nil }
                default: break
                }
                if event.modifierFlags.contains([.option, .command]),
                   event.charactersIgnoringModifiers?.lowercased() == "p" {
                    state.stopPresentation()
                    return nil
                }
                return event
            }
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if !(window?.styleMask.contains(.fullScreen) ?? false) {
            window?.toggleFullScreen(nil)
        }
    }

    func close() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        window?.orderOut(nil)
        state = nil
    }
}
