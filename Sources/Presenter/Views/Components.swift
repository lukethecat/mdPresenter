import SwiftUI
import AppKit
import PresenterCore

// MARK: - Liquid Glass
//
// macOS 26+ gets the real Liquid Glass effect (`glassEffect` with tint and
// interactivity, like Apple's redesigned iWork suite); macOS 11–25 falls
// back to an NSVisualEffectView approximation with the same specular rim.

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

extension View {
    /// Apply Liquid Glass to this view: real glass on macOS 26+, blur on older systems.
    @ViewBuilder
    func liquidGlass(
        cornerRadius: CGFloat = 14,
        tint: Color = Color.black.opacity(0.30),
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.background(
                VisualEffectBackground(material: .hudWindow, blending: .behindWindow)
                    .overlay(tint)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        }
    }

    /// The liquid-glass specular rim: light catches the top edge, shadow hugs the bottom.
    func glassRim(cornerRadius: CGFloat) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.22),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

/// A floating glass panel: content on tinted, refractive glass.
struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var tint: Color = Color.black.opacity(0.30)
    var innerPadding: CGFloat = 0
    let content: Content

    init(
        cornerRadius: CGFloat = 16,
        tint: Color = Color.black.opacity(0.30),
        innerPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.innerPadding = innerPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(innerPadding)
            .liquidGlass(cornerRadius: cornerRadius, tint: tint)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassRim(cornerRadius: cornerRadius)
    }
}

/// Ambient light behind the glass: deep ink base + a slow glow in the
/// current slide's progress pigment. The glass panels refract it.
struct AmbientBackground: View {
    var tint: Color

    var body: some View {
        ZStack {
            Color(hex: 0x0D0E11)
            RadialGradient(
                colors: [tint.opacity(0.14), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 820
            )
            RadialGradient(
                colors: [Color(hex: 0x232A3A).opacity(0.35), .clear],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 900
            )
        }
    }
}

// MARK: - Shared UI pieces

struct ToolbarButton: View {
    let systemName: String
    let help: String
    var isActive: Bool = false
    var accent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(accent ? .white : (isActive ? Color(hex: 0xF5C518) : Color(hex: 0xC7C9CE)))
                .frame(width: 28, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(GlassButtonStyle(isActive: isActive, accent: accent))
        .help(help)
    }
}

/// Capsule glass buttons — the macOS 26 toolbar idiom.
struct GlassButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var accent: Bool = false
    var accentColor: Color = Color(hex: 0x3B82F6)

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration.label
                .liquidGlass(
                    cornerRadius: 7,
                    tint: accent
                        ? accentColor.opacity(0.55)
                        : (isActive ? Color.white.opacity(0.10) : Color.white.opacity(0.06)),
                    interactive: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .glassRim(cornerRadius: 7)
                .opacity(configuration.isPressed ? 0.72 : 1)
        } else {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            accent
                                ? accentColor
                                : (isActive ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
                        )
                )
                .opacity(configuration.isPressed ? 0.72 : 1)
        }
    }
}

extension Color {
    /// macOS 11-safe AppKit → SwiftUI color bridging.
    init(_ nsColor: NSColor) {
        guard let c = nsColor.usingColorSpace(.sRGB) else {
            self = .clear
            return
        }
        self.init(
            .sRGB,
            red: Double(c.redComponent),
            green: Double(c.greenComponent),
            blue: Double(c.blueComponent),
            opacity: Double(c.alphaComponent)
        )
    }

    init(hex: UInt32) {
        self.init(NSColor(hex: hex))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Color(hex: 0x8A8F98))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// macOS 11-safe custom segmented control.
struct SegmentedPicker<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                Button(action: { selection = option.value }) {
                    Text(option.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selection == option.value ? .white : Color(hex: 0x9AA0A9))
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selection == option.value ? Color.white.opacity(0.14) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.3)))
    }
}

struct Chip: View {
    let text: String
    var color: Color = Color(hex: 0x8A8F98)
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.9)))
    }
}

/// Notes text with **bold** prompts emphasized — the teleprompter style.
struct NotesTextView: View {
    let blocks: [Block]
    var size: CGFloat = 13
    var dimColor: Color = Color(hex: 0xB9BCC4)
    var promptColor: Color = Color(hex: 0xFFD479)

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.7) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block.kind {
        case .bulletList:
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundColor(dimColor.opacity(0.6))
                        inlineLine(MarkdownParser.parseInline(line))
                    }
                }
            }
        case .orderedList:
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(block.lines.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1).").foregroundColor(dimColor.opacity(0.6))
                        inlineLine(MarkdownParser.parseInline(line))
                    }
                }
            }
        case .quote:
            HStack(alignment: .top, spacing: 6) {
                Rectangle().fill(dimColor.opacity(0.5)).frame(width: 2)
                inlineLine(block.inlines).italic()
            }
        case .fencedCode:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: size * 0.85, design: .monospaced))
                        .foregroundColor(dimColor)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
        default:
            inlineLine(block.inlines)
        }
    }

    private func inlineLine(_ inlines: [Inline]) -> Text {
        var result = Text("")
        for inline in inlines {
            switch inline {
            case .text(let s):
                result = result + Text(s).foregroundColor(dimColor)
            case .bold(let kids):
                var inner = Text("")
                for kid in kids {
                    if case .text(let s) = kid { inner = inner + Text(s) }
                }
                result = result + inner
                    .fontWeight(.bold)
                    .foregroundColor(promptColor)
            case .italic(let kids):
                var inner = Text("")
                for kid in kids {
                    if case .text(let s) = kid { inner = inner + Text(s) }
                }
                result = result + inner.italic().foregroundColor(dimColor)
            case .code(let s):
                result = result + Text(s)
                    .font(.system(size: size * 0.85, design: .monospaced))
                    .foregroundColor(promptColor)
            case .link(let kids, _):
                var inner = Text("")
                for kid in kids {
                    if case .text(let s) = kid { inner = inner + Text(s) }
                }
                result = result + inner.underline().foregroundColor(dimColor)
            case .lineBreak:
                result = result + Text("\n")
            }
        }
        return result.font(.system(size: size))
    }
}

// MARK: - Media drop support

import UniformTypeIdentifiers

struct MediaDropDelegate: DropDelegate {
    let state: AppState
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.image.identifier, UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) { isTargeted = true }
    func dropExited(info: DropInfo) { isTargeted = false }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let providers = info.itemProviders(for: [UTType.image.identifier, UTType.fileURL.identifier])
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data = data else { return }
                    DispatchQueue.main.async {
                        state.attachMedia(data: data, fileName: "粘贴图片.png", mime: "image/png")
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = item as? URL, let data = try? Data(contentsOf: url) else { return }
                    let mime = MimeType.forExtension(url.pathExtension)
                    DispatchQueue.main.async {
                        state.attachMedia(data: data, fileName: url.lastPathComponent, mime: mime)
                    }
                }
            }
        }
        return true
    }
}

enum MimeType {
    static func forExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "tif", "tiff": return "image/tiff"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4v": return "video/x-m4v"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        case "aiff": return "audio/aiff"
        case "flac": return "audio/flac"
        case "au": return "audio/basic"
        default: return "application/octet-stream"
        }
    }
}
