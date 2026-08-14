import AppKit
import Combine
import SwiftUI
import PresenterCore

// MARK: - Presentation Mode (Keynote-style fullscreen)
//
// ⌥⌘P opens a dedicated screen where the SLIDE ITSELF fills the entire
// display. The chrome is a floating, auto-hiding glass overlay: a thin
// progress bar, prev/next, the timer — and an optional teleprompter
// drawer (备注/缩略图) that slides in over the slide when you need it.

struct PresenterView: View {
    @EnvironmentObject var state: AppState
    @State private var mode: PresenterMode = .notes
    @State private var elapsed: TimeInterval = 0
    @State private var startDate = Date()
    @State private var controlsVisible = true
    @State private var hideTask: DispatchWorkItem?
    @State private var mouseMonitor: Any?
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

            ZStack {
                // 1. The slide fills the whole screen — content-first.
                stage(slideAspect: slideAspect)

                // 2. Floating, auto-hiding glass chrome.
                VStack(spacing: 0) {
                    topBar
                        .opacity(controlsVisible ? 1 : 0)
                    Spacer()
                    bottomControls
                        .opacity(controlsVisible ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.35))

                // 3. Optional teleprompter drawer over the slide.
                if state.presenterPanelVisible {
                    HStack {
                        Spacer()
                        teleprompterPanel(width: min(440, geo.size.width * 0.34))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    .animation(.easeInOut(duration: 0.35))
                }

                // 4. Progress hairline at the very bottom.
                VStack {
                    Spacer()
                    progressBar
                }
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(startDate)
        }
        .onAppear(perform: installControlAutoHide)
        .onDisappear(perform: removeControlAutoHide)
    }

    // MARK: Auto-hiding chrome

    private func installControlAutoHide() {
        // Any mouse activity reveals the chrome; 3s of stillness hides it.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel]
        ) { event in
            withAnimation(.easeInOut(duration: 0.3)) {
                controlsVisible = true
            }
            hideTask?.cancel()
            let task = DispatchWorkItem {
                withAnimation(.easeInOut(duration: 0.5)) {
                    controlsVisible = false
                }
            }
            hideTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: task)
            return event
        }
    }

    private func removeControlAutoHide() {
        hideTask?.cancel()
        hideTask = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Teleprompter drawer toggle.
            Button(action: { state.presenterPanelVisible.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                    Text("提词器")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(GlassButtonStyle(isActive: state.presenterPanelVisible))
            .help("显示/隐藏提词器 (N)")

            Spacer()

            if let content = currentContent {
                let color = ProgressColorEngine.color(at: content.progress)
                HStack(spacing: 8) {
                    Circle().fill(Color(color)).frame(width: 8, height: 8)
                    Text(stageName(ProgressColorEngine.stageName(at: content.progress)))
                        .foregroundColor(Color(color))
                    Text("\(state.presenterIndex + 1) / \(max(1, state.deck.contents.count))")
                        .foregroundColor(Color(hex: 0xB9BCC4))
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liquidGlass(cornerRadius: 9, tint: Color.black.opacity(0.4), interactive: false)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            Button(action: { startDate = Date(); elapsed = 0 }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(clockString(elapsed))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(GlassButtonStyle())
            .help("点击重置计时器")

            Button(action: { state.stopPresentation() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.white)
                    .frame(width: 30, height: 26)
            }
            .buttonStyle(GlassButtonStyle(accent: true, accentColor: Color(hex: 0xE53935)))
            .help("停止演示 (⌥⌘P / Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: Bottom controls

    private var bottomControls: some View {
        HStack(spacing: 10) {
            Button(action: { state.presenterPrevious() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 28)
            }
            .buttonStyle(GlassButtonStyle())
            .help("上一张 (←)")

            Button(action: { state.presenterNext() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 28)
            }
            .buttonStyle(GlassButtonStyle())
            .help("下一张 (→ / 空格 / 点击)")
        }
        .padding(.bottom, 14)
    }

    // MARK: Stage — the slide owns the screen

    private func stage(slideAspect: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: 0x0B0C0E)
                // The stage breathes with the slide's own pigment.
                if let content = currentContent {
                    let style = state.slideStyle(for: content)
                    RadialGradient(
                        colors: [
                            Color(style.background.first ?? .black).opacity(0.16),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 720
                    )
                    .animation(.easeInOut(duration: 1.0))
                }
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
                    .onTapGesture { state.presenterNext() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Teleprompter drawer

    private func teleprompterPanel(width: CGFloat) -> some View {
        GlassPanel(cornerRadius: 20, tint: Color.black.opacity(0.48)) {
            VStack(spacing: 0) {
                HStack {
                    SegmentedPicker(
                        options: [(PresenterMode.notes, "备注"), (PresenterMode.thumbnails, "缩略图")],
                        selection: $mode
                    )
                    .frame(width: 170)
                    Spacer()
                }
                .padding(12)
                Divider().background(Color.white.opacity(0.08))
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
        .frame(height: 4)
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
        case "Blue": return "Blue · 冷启动"
        case "Indigo": return "Indigo · 预热"
        case "Red": return "Red · 高潮"
        case "Orange": return "Orange · 收尾"
        case "Gold": return "Gold · 余韵"
        default: return raw
        }
    }
}

// MARK: - Presenter window (AppKit shell)

final class PresenterWindowController: NSObject, NSWindowDelegate {
    static let shared = PresenterWindowController()

    private var window: NSWindow?
    private var keyMonitor: Any?
    private var fallbackWork: DispatchWorkItem?
    private weak var state: AppState?

    /// Exposed for tests / diagnostics.
    var isWindowVisible: Bool { window?.isVisible ?? false }
    var currentWindow: NSWindow? { window }

    // A borderless window entering a fullscreen Space otherwise keeps its
    // own (possibly small) frame — the delegate must claim the whole screen.
    func window(_ window: NSWindow, willUseFullScreenContentSize proposedSize: NSSize) -> NSSize {
        (window.screen ?? NSScreen.main)?.frame.size ?? proposedSize
    }

    func present(state: AppState) {
        self.state = state
        if window == nil {
            // Target the screen the user is looking at (mouse), then key
            // window's screen, then the main screen.
            let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            let screen = mouseScreen ?? NSScreen.main ?? NSScreen.screens.first
            let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            NSLog("Presenter: target screen \(NSStringFromRect(screen?.frame ?? .zero))")

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
            // `.fullScreenAuxiliary` would silently block toggleFullScreen —
            // use `.fullScreenPrimary` so the presenter can own a Space.
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
            win.delegate = self
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
                case 45: state.presenterPanelVisible.toggle(); return nil // n: 提词器
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

        guard let window = window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.orderFrontRegardless()
        }

        // Stage 1: a real fullscreen Space (with delegate-provided size).
        DispatchQueue.main.async { [weak self, weak state] in
            guard let self = self, let window = self.window,
                  let state = state, state.isPresenting else { return }
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            self.scheduleFallback(window: window, state: state)
        }
    }

    /// Stage 2: if the Space didn't happen within ~1.2s, cover the whole
    /// screen deterministically at the shielding level (menu bar included).
    private func scheduleFallback(window: NSWindow, state: AppState) {
        fallbackWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak state] in
            guard let self = self, let window = self.window,
                  let state = state, state.isPresenting else { return }
            let screen = window.screen ?? NSScreen.main
            if !window.styleMask.contains(.fullScreen) {
                if let screen = screen {
                    window.setFrame(screen.frame, display: true)
                }
                window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
                NSLog("Presenter: fullscreen Space unavailable — kiosk overlay \(window.frame), level \(window.level.rawValue)")
            } else {
                // Inside the Space: guarantee the borderless window fills it.
                if let screen = screen {
                    window.setFrame(screen.frame, display: true)
                }
                window.level = .normal
                NSLog("Presenter: fullscreen Space active — frame \(window.frame)")
            }
        }
        fallbackWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func close() {
        fallbackWork?.cancel()
        fallbackWork = nil
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        guard let window = window else {
            state = nil
            return
        }
        window.level = .normal
        if window.styleMask.contains(.fullScreen) {
            // Exit the fullscreen Space explicitly — ordering out alone
            // leaves a black, window-less Space behind (Esc → 黑屏 bug).
            // windowDidExitFullScreen hides the window once we're back.
            DispatchQueue.main.async {
                window.toggleFullScreen(nil)
            }
            // Guaranteed cleanup: if the exit animation stalls, force-hide.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                window.orderOut(nil)
            }
        } else {
            window.orderOut(nil)
        }
        state = nil
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        (notification.object as? NSWindow)?.orderOut(nil)
    }
}
