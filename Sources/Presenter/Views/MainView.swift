import SwiftUI
import UniformTypeIdentifiers
import PresenterCore

// MARK: - Main window
//
// Content-first, three-pane layout: thumbnails | editor | preview +
// inspector. Everything is collapsible; ⌘D leaves only the editor.

struct MainView: View {
    @EnvironmentObject var state: AppState
    @State private var isDropTargeted = false

    var body: some View {
        HSplitView {
            if state.showThumbnails {
                ThumbnailsView()
                    .frame(minWidth: 180, idealWidth: 215, maxWidth: 290)
            }

            editorPane
                .frame(minWidth: 360, idealWidth: 560)

            if state.showPreview {
                SlidePreviewPanel()
                    .frame(minWidth: 300, idealWidth: 420, maxWidth: 560)
            }

            if state.showInspector {
                InspectorView()
                    .frame(minWidth: 250, idealWidth: 272, maxWidth: 320)
            }
        }
        .background(
            FluidBackground(
                id: ambientID,
                pigments: ambientPigments,
                accent: ProgressColorEngine.color(at: progress)
            )
            .ignoresSafeArea()
        )
        .background(TransparentWindowConfigurator())
        .onDrop(
            of: [UTType.image.identifier, UTType.fileURL.identifier],
            delegate: MediaDropDelegate(state: state, isTargeted: $isDropTargeted)
        )
        .frame(minWidth: 1024, minHeight: 640)
        .toolbar {
            MainToolbar(state: state)
        }
        .onAppear {
            DispatchQueue.main.async {
                state.editorCommand.send(.focusEditor)
            }
        }
    }

    /// The current slide's own background pigments — the fluid backdrop
    /// IS the slide's color, flowing from 石青 to 宫墙红 as you move.
    private var ambientPigments: [NSColor] {
        guard let content = state.currentContent else {
            return [NSColor(hex: 0x2E5F88)]
        }
        return state.slideStyle(for: content).background
    }

    private var ambientID: String {
        "\(state.currentSlide)-\(state.settings.themeId)-\(state.settings.colorMode.rawValue)"
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                EditorView(state: state)

                if state.turboBanner {
                    TurboStartBanner()
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .liquidGlass(
                cornerRadius: 16,
                tint: Color.black.opacity(state.currentSlideIsLight ? 0.36 : 0.22)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glassRim(cornerRadius: 16)
            .padding(10)
            statusBar
        }
    }

    private var statusBar: some View {
        GlassPanel(
            cornerRadius: 13,
            tint: Color.black.opacity(state.currentSlideIsLight ? 0.32 : 0.16)
        ) {
            HStack(spacing: 14) {
                Text("\(state.slideCount) 张幻灯片")
                Text("\(state.wordCount) 字")
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(ProgressColorEngine.color(at: progress)))
                        .frame(width: 7, height: 7)
                    Text(ProgressColorEngine.stageName(at: progress))
                }
                Text(state.totalEstimateLabel)
                    .foregroundColor(Color(hex: 0xF5C518))
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(Color(hex: 0x9AA0A9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var progress: Double {
        guard state.deck.contents.count > 1 else { return 0 }
        return Double(state.currentSlide) / Double(state.deck.contents.count - 1)
    }
}

// MARK: - TurboStart banner

private struct TurboStartBanner: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundColor(Color(hex: 0xF5C518))
            VStack(alignment: .leading, spacing: 1) {
                Text("TurboStart")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("这段文本还没有分页，要自动拆分成幻灯片吗？")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: 0xB9BCC4))
            }
            Spacer()
            Button("拆分") { state.applyTurboStart() }
                .buttonStyle(TurboButtonStyle())
            Button("忽略") { state.turboBanner = false }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(Color(hex: 0x9AA0A9))
                .font(.system(size: 11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(cornerRadius: 12, tint: Color.black.opacity(state.currentSlideIsLight ? 0.40 : 0.28), interactive: true)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassRim(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xF5C518).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 14, y: 5)
        .padding(.horizontal, 60)
    }
}

struct TurboButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: 0x1B1C1F))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(hex: 0xF5C518)))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
