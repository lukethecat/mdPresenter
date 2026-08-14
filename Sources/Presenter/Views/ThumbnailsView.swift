import SwiftUI
import PresenterCore

// MARK: - Slide thumbnails (left panel)

struct ThumbnailsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        GlassPanel(cornerRadius: 16, tint: Color.black.opacity(0.14)) {
            VStack(spacing: 0) {
                HStack {
                    Text("幻灯片")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(Color(hex: 0x9AA0A9))
                    Spacer()
                    Text("\(state.slideCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: 0x6E7279))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider().background(Color.white.opacity(0.07))

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(state.deck.contents.indices, id: \.self) { index in
                            ThumbnailCell(
                                content: state.deck.contents[index],
                                isCurrent: index == state.currentSlide,
                                onSelect: { state.selectSlide(index) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .padding(10)
    }
}

private struct ThumbnailCell: View {
    @EnvironmentObject var state: AppState
    let content: SlideContent
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        let style = state.slideStyle(for: content)
        let minutes = SpeechTimer.estimatedMinutes(slide: content)
        let progressColor = ProgressColorEngine.color(at: content.progress)

        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(content.index + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(progressColor.luminance > 0.5 ? Color(hex: 0x16171A) : .white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color(progressColor)))
                    Spacer()
                    Text(SpeechTimer.label(minutes: minutes))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: 0x6E7279))
                }
                SlideCanvas(
                    content: content,
                    style: style,
                    settings: state.settings,
                    media: state.media
                )
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isCurrent ? Color(progressColor) : Color.white.opacity(0.08),
                            lineWidth: isCurrent ? 2 : 1
                        )
                )
                Text(content.headline?.plainText ?? content.title?.plainText ?? "幻灯片 \(content.index + 1)")
                    .font(.system(size: 10.5, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? .white : Color(hex: 0x9AA0A9))
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help("第 \(content.index + 1) 张 · \(SpeechTimer.label(minutes: minutes))")
    }
}
