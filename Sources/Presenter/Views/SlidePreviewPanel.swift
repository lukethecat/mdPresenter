import SwiftUI
import UniformTypeIdentifiers
import PresenterCore

// MARK: - Live slide preview (right of the editor)
//
// iA shows Desktop / Mobile previews; the Design engine makes the same
// slide fit any canvas.

struct SlidePreviewPanel: View {
    @EnvironmentObject var state: AppState
    @State private var showNotes = true
    @State private var isDropTargeted = false

    var body: some View {
        GlassPanel(cornerRadius: 16, tint: Color.black.opacity(state.currentSlideIsLight ? 0.32 : 0.14)) {
            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.07))
                previewArea
                Divider().background(Color.white.opacity(0.07))
                notesArea
            }
        }
        .padding(10)
        .onDrop(
            of: [UTType.image.identifier, UTType.fileURL.identifier],
            delegate: MediaDropDelegate(state: state, isTargeted: $isDropTargeted)
        )
        .simultaneousGesture(
            TapGesture().onEnded { state.activeRegion = .preview }
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            SegmentedPicker(
                options: [
                    (AppState.PreviewDevice.desktop, "Desktop"),
                    (AppState.PreviewDevice.mobile, "Mobile"),
                ],
                selection: $state.previewDevice
            )
            .frame(width: 150)
            Spacer()
            if let content = state.currentContent {
                let color = ProgressColorEngine.color(at: content.progress)
                Circle().fill(Color(color)).frame(width: 8, height: 8)
                Text("\(content.index + 1) / \(max(1, state.slideCount))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: 0x9AA0A9))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var previewAspect: CGFloat {
        if let ratio = state.settings.aspect.ratio { return ratio }
        return state.previewDevice == .desktop ? 16.0 / 9.0 : 9.0 / 16.0
    }

    private var previewArea: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.22)
                if let content = state.currentContent {
                    let style = state.slideStyle(for: content)
                    let available = geo.size
                    let fitRatio = available.width / max(1, available.height)
                    let targetRatio = previewAspect
                    let slideW: CGFloat = fitRatio > targetRatio
                        ? available.height * targetRatio
                        : available.width
                    let slideH: CGFloat = fitRatio > targetRatio
                        ? available.height
                        : available.width / targetRatio
                    SlideCanvas(
                        content: content,
                        style: style,
                        settings: state.settings,
                        media: state.media,
                        layoutOverride: state.layoutOverride(for: content.index)
                    )
                    .frame(width: slideW, height: slideH)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                } else {
                    Text("开始写作\n三次回车创建新幻灯片")
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(hex: 0x6E7279))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                isDropTargeted
                    ? RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(LiquidGlassPalette.systemBlue), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .padding(12)
                    : nil
            )
        }
        .padding(12)
    }

    private var notesArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { showNotes.toggle() }) {
                HStack {
                    Image(systemName: showNotes ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("备注 — 观众看不到")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                    Spacer()
                    if let content = state.currentContent {
                        Text(SpeechTimer.label(minutes: SpeechTimer.estimatedMinutes(slide: content)))
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .foregroundColor(Color(hex: 0x8A8F98))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showNotes {
                ScrollView {
                    if let content = state.currentContent, !content.notes.isEmpty {
                        NotesTextView(blocks: content.notes, size: 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("这张幻灯片还没有备注。正文段落会出现在这里，只有你自己看得到。")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: 0x6E7279))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxHeight: showNotes ? 150 : 40)
    }
}
