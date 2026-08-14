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

/// Fluid glass backdrop — water, not black.
///
/// The window background IS the current slide's pigments. A colored wash
/// (dimmed only as much as readability requires) is overlaid with five
/// large soft blobs of pure pigment — brightened and deepened variants —
/// that drift on slow Lissajous paths like water moving across glass.
/// When the slide changes, the whole palette morphs over ~1.5s, and the
/// wash's gradient direction slowly rotates. On macOS 11 the blobs are
/// static; macOS 12+ gets the full flowing animation.
struct FluidBackground: View {
    var id: String = ""
    var pigments: [NSColor] = [NSColor(hex: 0x2E5F88)]
    var accent: NSColor = NSColor(hex: 0x1F6FB2)

    @State private var washColors: [Color] = [
        Color(NSColor(hex: 0x35678F)), Color(NSColor(hex: 0x2A4460)),
    ]
    @State private var glowColors: [Color] = [
        Color(NSColor(hex: 0x2E5F88)), Color(NSColor(hex: 0x2E5F88)),
        Color(NSColor(hex: 0x5E8AB5)), Color(NSColor(hex: 0x6F97BE)),
        Color(NSColor(hex: 0x1C3A57)),
    ]
    @State private var accentColor: Color = Color(NSColor(hex: 0x1F6FB2))

    var body: some View {
        field(time: 0)
            .onAppear(perform: syncPalette)
            .onChange(of: id) { _ in
                withAnimation(.easeInOut(duration: 1.5)) {
                    syncPalette()
                }
            }
    }

    // MARK: Palette

    private func syncPalette() {
        let fallback = NSColor(hex: 0x2E5F88)
        let c0 = pigments.first ?? fallback
        let c1 = pigments.count > 1 ? pigments[1] : c0

        // Wash: the slide color itself. Light pigments are dimmed a little
        // so chrome text stays readable; dark pigments are lifted slightly.
        let washA = c0.isDark ? c0.mixed(with: .white, t: 0.06) : c0.mixed(with: .black, t: 0.46)
        let washB = c1.isDark ? c1.mixed(with: .white, t: 0.04) : c1.mixed(with: .black, t: 0.50)
        washColors = [Color(washA), Color(washB)]

        // Glows: pure pigment plus brightened/deepened water variants.
        glowColors = [
            Color(c0),
            Color(c1),
            Color(c0.mixed(with: .white, t: 0.34)),
            Color(c1.mixed(with: .white, t: 0.42)),
            Color(c1.mixed(with: .black, t: 0.18)),
        ]
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
                // Slow-drifting colored wash.
                LinearGradient(
                    gradient: Gradient(colors: [washColors[0].opacity(0.92), washColors[1].opacity(0.88)]),
                    startPoint: UnitPoint(
                        x: 0.25 + 0.18 * CGFloat(sin(time * 0.05)),
                        y: 0.1 + 0.1 * CGFloat(cos(time * 0.04))
                    ),
                    endPoint: UnitPoint(
                        x: 0.8 + 0.15 * CGFloat(cos(time * 0.037 + 1.2)),
                        y: 0.95 + 0.08 * CGFloat(sin(time * 0.045 + 0.6))
                    )
                )

                // The water: five pigment blobs on slow Lissajous drift.
                blob(glowColors[0], time, speed: 0.10, phase: 0.0, size: w * 0.85, at: CGPoint(x: w * 0.24, y: h * 0.30))
                blob(glowColors[1], time, speed: 0.08, phase: 2.4, size: w * 0.72, at: CGPoint(x: w * 0.78, y: h * 0.70))
                blob(glowColors[2], time, speed: 0.12, phase: 4.1, size: w * 0.52, at: CGPoint(x: w * 0.66, y: h * 0.24))
                blob(glowColors[3], time, speed: 0.07, phase: 1.3, size: w * 0.58, at: CGPoint(x: w * 0.30, y: h * 0.86))
                blob(glowColors[4], time, speed: 0.09, phase: 5.2, size: w * 0.42, at: CGPoint(x: w * 0.5, y: h * 0.5))
                blob(accentColor, time, speed: 0.06, phase: 3.0, size: w * 0.34, at: CGPoint(x: w * 0.14, y: h * 0.12))
            }
        }
    }

    private func blob(
        _ color: Color,
        _ time: TimeInterval,
        speed: Double,
        phase: Double,
        size: CGFloat,
        at center: CGPoint
    ) -> some View {
        let drift = blobDrift(time, speed: speed, phase: phase, radius: size * 0.30)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.46), color.opacity(0.0)],
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
