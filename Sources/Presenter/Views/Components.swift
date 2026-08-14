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
    var tint: Color = Color.black.opacity(0.14)
    var innerPadding: CGFloat = 0
    let content: Content

    init(
        cornerRadius: CGFloat = 16,
        tint: Color = Color.black.opacity(0.14),
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

/// Liquid Glass design tokens, researched from Apple's post-WWDC25 HIG
/// (via hig-mcp) and sampled directly from the macOS Tahoe wallpapers.
enum LiquidGlassPalette {
    // Post-WWDC25 system colors, dark appearance (HIG 2025-06-09 refresh:
    // systemBlue is no longer #007AFF).
    static let systemBlue = NSColor(hex: 0x0091FF)
    static let systemYellow = NSColor(hex: 0xFFD600)

    // Sampled from /System/Library/Desktop Pictures — "Mac Blue" and
    // "Chroma Blue" (the macOS 26/27 liquid-glass wallpapers).
    static let inkTop = NSColor(hex: 0x0A1226)
    static let inkBottom = NSColor(hex: 0x0E1B3A)
    static let water: [NSColor] = [
        NSColor(hex: 0x4A9CEE),   // azure
        NSColor(hex: 0x6AD5F6),   // cyan
        NSColor(hex: 0xAC9CE6),   // lavender
        NSColor(hex: 0xACD5F6),   // periwinkle
    ]
}

/// Fluid glass backdrop, following the researched Liquid Glass guardrails:
///   • translucent wash (never opaque — the desktop reads through),
///   • ≤ 4 compositing layers (wash + 3 water blobs + whisper),
///   • soft frost (large soft radial gradients, no hard blur),
///   • mandatory Reduce-Transparency fallback: solid variant at runtime.
///
/// The water ribbons use macOS Tahoe's own wallpaper pigments; the current
/// slide's pigment stays as a low whisper so themes still tint the ambience.
struct FluidBackground: View {
    var id: String = ""
    var pigments: [NSColor] = [NSColor(hex: 0x2E5F88)]
    var accent: NSColor = NSColor(hex: 0x1F6FB2)

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var whisperColor: Color = Color(NSColor(hex: 0x2E5F88))
    @State private var accentColor: Color = Color(NSColor(hex: 0x1F6FB2))
    private let waterColors: [Color] = LiquidGlassPalette.water.map { Color($0) }

    var body: some View {
        field(time: 0)
            .onAppear(perform: syncPalette)
            .onChange(of: id) { _ in
                withAnimation(.easeInOut(duration: 1.5)) {
                    syncPalette()
                }
            }
    }

    private func syncPalette() {
        whisperColor = Color(pigments.first ?? NSColor(hex: 0x2E5F88))
        accentColor = Color(accent)
    }

    // MARK: Field

    @ViewBuilder
    private func field(time: TimeInterval) -> some View {
        if #available(macOS 12.0, *) {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                fieldBody(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            fieldBody(time: 0)
        }
    }

    private func fieldBody(time: TimeInterval) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Translucent ink wash — transparency, not black. With
                // Reduce Transparency it becomes solid (HIG fallback rule).
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(LiquidGlassPalette.inkTop).opacity(reduceTransparency ? 1.0 : 0.58),
                        Color(LiquidGlassPalette.inkBottom).opacity(reduceTransparency ? 1.0 : 0.52),
                    ]),
                    startPoint: UnitPoint(
                        x: 0.25 + 0.18 * CGFloat(sin(time * 0.05)),
                        y: 0.1 + 0.1 * CGFloat(cos(time * 0.04))
                    ),
                    endPoint: UnitPoint(
                        x: 0.8 + 0.15 * CGFloat(cos(time * 0.037 + 1.2)),
                        y: 0.95 + 0.08 * CGFloat(sin(time * 0.045 + 0.6))
                    )
                )

                if !reduceTransparency {
                    // Three water ribbons (Tahoe pigments) on slow drift.
                    blob(waterColors[0], time, speed: 0.09, phase: 0.0, size: w * 0.78, opacity: 0.30, at: CGPoint(x: w * 0.26, y: h * 0.32))
                    blob(waterColors[1], time, speed: 0.07, phase: 2.4, size: w * 0.62, opacity: 0.26, at: CGPoint(x: w * 0.76, y: h * 0.68))
                    blob(waterColors[2], time, speed: 0.11, phase: 4.1, size: w * 0.55, opacity: 0.24, at: CGPoint(x: w * 0.6, y: h * 0.22))
                    blob(waterColors[3], time, speed: 0.06, phase: 1.3, size: w * 0.5, opacity: 0.20, at: CGPoint(x: w * 0.32, y: h * 0.82))

                    // The current slide's pigment — a quiet whisper.
                    blob(whisperColor, time, speed: 0.05, phase: 5.2, size: w * 0.46, opacity: 0.16, at: CGPoint(x: w * 0.5, y: h * 0.5))
                    blob(accentColor, time, speed: 0.06, phase: 3.0, size: w * 0.28, opacity: 0.12, at: CGPoint(x: w * 0.14, y: h * 0.12))
                }
            }
        }
    }

    private func blob(
        _ color: Color,
        _ time: TimeInterval,
        speed: Double,
        phase: Double,
        size: CGFloat,
        opacity: Double,
        at center: CGPoint
    ) -> some View {
        let drift = blobDrift(time, speed: speed, phase: phase, radius: size * 0.30)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .position(x: center.x + drift.width, y: center.y + drift.height)
    }

    private func blobDrift(_ t: TimeInterval, speed: Double, phase: Double, radius: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(sin(t * speed + phase)) * radius,
            height: CGFloat(cos(t * speed * 0.83 + phase * 1.6)) * radius * 0.75
        )
    }
}

/// Makes the window itself transparent so Liquid Glass can refract the
/// desktop and the fluid background — no more opaque black window backdrop.
struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.hasShadow = true
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
                .foregroundColor(accent ? .white : (isActive ? Color(hex: 0xFFD600) : Color(hex: 0xC7C9CE)))
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
    var accentColor: Color = Color(LiquidGlassPalette.systemBlue)

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
