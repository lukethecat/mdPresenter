import AppKit
import SwiftUI
import PresenterCore

// MARK: - App entry

@main
struct PresenterApp: App {
    private let state = AppState.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            commandMenus
        }
    }

    @CommandsBuilder
    private var commandMenus: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建演示文稿") { ExportCoordinator.newDocument(state, blank: false) }
                .keyboardShortcut("n")
            Button("新建空白文稿") { ExportCoordinator.newDocument(state, blank: true) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .saveItem) {
            Button("保存") { ExportCoordinator.saveDocument(state) }
                .keyboardShortcut("s")
            Button("存储为…") { ExportCoordinator.saveDocument(state, saveAs: true) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        CommandMenu("打开") {
            Button("打开文稿…") { ExportCoordinator.openDocument(state) }
                .keyboardShortcut("o")
            Divider()
            Button("导入 Markdown / 文本（TurboStart）") { ExportCoordinator.openDocument(state) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
        CommandMenu("导出") {
            Button("幻灯片 PDF…") { ExportCoordinator.exportSlidesPDF(state) }
                .keyboardShortcut("e")
            Button("讲义 PDF（可读摘要）…") { ExportCoordinator.exportHandoutPDF(state) }
            Button("Markdown…") { ExportCoordinator.exportMarkdown(state) }
            Button("摘要 Markdown…") { ExportCoordinator.exportSummaryMarkdown(state) }
            Button("iA Presenter 格式 (.iapresenter)…") { ExportCoordinator.exportIAPresenter(state) }
            Button("幻灯片 PNG 图片…") { ExportCoordinator.exportImages(state) }
        }
        CommandMenu("演示") {
            Button("播放演示（演讲者视图）") { state.startPresentation() }
                .keyboardShortcut("p", modifiers: [.option, .command])
            Button("停止演示") { state.stopPresentation() }
                .keyboardShortcut(".", modifiers: [.option, .command])
        }
        CommandMenu("视图") {
            Button("聚焦模式") { state.focusMode.toggle() }
                .keyboardShortcut("d", modifiers: .command)
            Divider()
            Button("显示/隐藏缩略图") { state.showThumbnails.toggle() }
            Button("显示/隐藏预览") { state.showPreview.toggle() }
            Button("显示/隐藏检查器") { state.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.option, .command])
        }
    }
}

// MARK: - App delegate
//
// Makes `swift run` behave like a real app: regular activation policy,
// frontmost window, quit on last window close. Also routes the arrow keys
// to whichever region the user last interacted with.

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        installRegionKeyMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Region-aware arrow keys: after interacting with the thumbnails or
    /// the preview, ↑/↓ move between slides instead of moving the editor
    /// caret. Text controls always keep their own keys.
    private func installRegionKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let state = AppState.shared
            guard !state.isPresenting else { return event }

            // A text control owns the keyboard — hands off.
            if let responder = NSApp.keyWindow?.firstResponder as? NSView,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            switch state.activeRegion {
            case .thumbnails, .preview:
                switch event.keyCode {
                case 126: // ↑
                    state.selectSlide(max(0, state.currentSlide - 1))
                    return nil
                case 125: // ↓
                    state.selectSlide(min(state.slideCount - 1, state.currentSlide + 1))
                    return nil
                default:
                    break
                }
            case .editor:
                break
            }
            return event
        }
    }
}

// MARK: - Toolbar

struct MainToolbar: ToolbarContent {
    @ObservedObject var state: AppState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            ToolbarButton(systemName: "square.and.pencil", help: "新建演示文稿") {
                ExportCoordinator.newDocument(state, blank: false)
            }
            ToolbarButton(systemName: "folder", help: "打开…") {
                ExportCoordinator.openDocument(state)
            }
            ToolbarButton(systemName: "square.and.arrow.down", help: "保存") {
                ExportCoordinator.saveDocument(state)
            }
        }

        ToolbarItem(placement: .principal) {
            TextField("文稿标题", text: $state.documentTitle, onCommit: {})
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 180)
                .foregroundColor(.white)
        }

        ToolbarItemGroup(placement: .automatic) {
            ToolbarButton(
                systemName: "scope",
                help: "聚焦模式 (⌘D)",
                isActive: state.focusMode
            ) {
                state.focusMode.toggle()
            }
            ToolbarButton(
                systemName: "rectangle.3.offgrid",
                help: "缩略图",
                isActive: state.showThumbnails
            ) {
                state.showThumbnails.toggle()
            }
            ToolbarButton(
                systemName: "play.rectangle",
                help: "幻灯片预览",
                isActive: state.showPreview
            ) {
                state.showPreview.toggle()
            }
            ToolbarButton(
                systemName: "slider.horizontal.3",
                help: "检查器 (⌥⌘I)",
                isActive: state.showInspector
            ) {
                state.showInspector.toggle()
            }

            Menu {
                Button("幻灯片 PDF…") { ExportCoordinator.exportSlidesPDF(state) }
                Button("讲义 PDF（可读摘要）…") { ExportCoordinator.exportHandoutPDF(state) }
                Button("Markdown…") { ExportCoordinator.exportMarkdown(state) }
                Button("摘要 Markdown…") { ExportCoordinator.exportSummaryMarkdown(state) }
            Button("iA Presenter 格式 (.iapresenter)…") { ExportCoordinator.exportIAPresenter(state) }
                Button("幻灯片 PNG 图片…") { ExportCoordinator.exportImages(state) }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: 0xB9BCC4))
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .help("导出")

            Button(action: { state.startPresentation() }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("演示")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
            .buttonStyle(GlassButtonStyle(accent: true, accentColor: Color(LiquidGlassPalette.systemBlue)))
            .help("播放演示 (⌥⌘P)")
        }
    }
}
