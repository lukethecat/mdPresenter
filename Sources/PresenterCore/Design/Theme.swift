import AppKit
import Foundation

// MARK: - Themes
//
// 内置主题取材于中国传统美学：敦煌壁画的矿物颜料、故宫的宫墙红与
// 琉璃金、汝窑天青、水墨的五色与留白…… 每个主题都带明暗两套版本，
// 颜色随幻灯片推进而轮换。

public struct SlideStyle {
    /// Background colors; more than one = top-to-bottom gradient.
    public var background: [NSColor]
    public var textColor: NSColor
    public var headlineColor: NSColor
    public var kickerColor: NSColor
    public var accent: NSColor
    public var pageColor: NSColor
    public var headlineFamily: String
    public var headlineWeight: NSFont.Weight
    public var headlineScale: CGFloat          // relative headline size
    public var uppercaseKicker: Bool
    public var centerContent: Bool
    public var useHairlineDivider: Bool
}

public struct Theme: Identifiable {
    public let id: String
    public let name: String
    public let tagline: String
    public let kind: String                    // 画彩 / 宫苑 / 瓷器 / 极简 / 粉彩 …
    public let style: (Int, Int, ColorMode) -> SlideStyle

    public init(id: String, name: String, tagline: String, kind: String,
                style: @escaping (Int, Int, ColorMode) -> SlideStyle) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.kind = kind
        self.style = style
    }

    // MARK: Registry

    public static func all() -> [Theme] {
        [glass, dunhuang, gugong, qinghua, ru, shuimo, jiangnan, wuxing, chajing, zhuqing]
    }

    public static func theme(id: String) -> Theme {
        all().first { $0.id == id } ?? glass
    }
}

// MARK: - 现代玻璃色板

enum GlassPalette {
    /// Post-WWDC25 system colors (Apple HIG 2025-06-09 refresh), dark appearance.
    static let blue = NSColor(hex: 0x0091FF)
    static let indigo = NSColor(hex: 0x6D7CFF)
    static let teal = NSColor(hex: 0x00D2E0)
    static let purple = NSColor(hex: 0xDB34F2)
    static let gray = NSColor(hex: 0x8E8E93)
    /// Deep ink base sampled from the macOS Tahoe "Chroma Blue" wallpaper.
    static let ink = NSColor(hex: 0x0A1226)

    /// Liquid-glass slide gradients: deep ink sinking into a system hue.
    static let gradients: [[NSColor]] = [
        [NSColor(hex: 0x0A1226), NSColor(hex: 0x0E3A78)], // → systemBlue
        [NSColor(hex: 0x0E1230), NSColor(hex: 0x3A2F8A)], // → systemIndigo
        [NSColor(hex: 0x08222C), NSColor(hex: 0x0B5664)], // → systemTeal
        [NSColor(hex: 0x170B2C), NSColor(hex: 0x5A2078)], // → systemPurple
        [NSColor(hex: 0x0A1226), NSColor(hex: 0x14213A)], // → ink
    ]

    /// Light-mode gradients: airy pastels carrying REAL system hues —
    /// sampled from the macOS "Mac Blue / Mac Purple" light wallpapers,
    /// never washed-out grey.
    static let gradientsLight: [[NSColor]] = [
        [NSColor(hex: 0xE4F0FC), NSColor(hex: 0x9CC9F2)], // periwinkle → systemBlue
        [NSColor(hex: 0xEDEBFB), NSColor(hex: 0xAFA9F2)], // lavender → systemIndigo
        [NSColor(hex: 0xE4F6F7), NSColor(hex: 0x93DFE6)], // ice → systemTeal
        [NSColor(hex: 0xF6E8FA), NSColor(hex: 0xD9A3EF)], // orchid → systemPurple
        [NSColor(hex: 0xEEF1F5), NSColor(hex: 0xC4CDDA)], // silver ink
    ]
    static let accents: [NSColor] = [blue, indigo, teal, purple, gray]

    /// Light-mode ink: deep slate for headline/text contrast on pastels.
    static let inkLight = NSColor(hex: 0x14213A)
    static let pageLight = NSColor(hex: 0x5F6B7A)
}

// MARK: - 传统色板

enum Palette {
    /// 敦煌壁画矿物颜料：石青、石绿、朱砂、赭石、土黄、黛紫、竹青、藏蓝。
    static let dunhuang: [NSColor] = [
        NSColor(hex: 0x2E5F88), NSColor(hex: 0x3E8E7E), NSColor(hex: 0xC3272B),
        NSColor(hex: 0xC96A2F), NSColor(hex: 0xD9A441), NSColor(hex: 0x4A3F6B),
        NSColor(hex: 0x5B8C5A), NSColor(hex: 0x264D8C),
    ]
    /// 江南粉彩：月白、藕荷、竹青、米白、黛蓝。
    static let jiangnan: [NSColor] = [
        NSColor(hex: 0xDCE9EA), NSColor(hex: 0xE8D4D8), NSColor(hex: 0xC9DCC8),
        NSColor(hex: 0xF2EEE4), NSColor(hex: 0xC3CDD9),
    ]
    /// 茶境：茶汤、熟褐、米白、岩茶。
    static let tea: [NSColor] = [
        NSColor(hex: 0xB08A5A), NSColor(hex: 0x8C5A2B), NSColor(hex: 0xF0E7D8),
        NSColor(hex: 0xA2703E),
    ]
    /// 竹青：竹青、新竹、深竹、米白。
    static let bamboo: [NSColor] = [
        NSColor(hex: 0x789262), NSColor(hex: 0x9DBB7C), NSColor(hex: 0x4E7A4A),
        NSColor(hex: 0xF2F0E6),
    ]

    static let gugongGold = NSColor(hex: 0xC9A063)
    static let gugongRed = NSColor(hex: 0x9E2A22)
    static let qinghuaCobalt = NSColor(hex: 0x1F4E8C)
    static let porcelainLight: [NSColor] = [NSColor(hex: 0xF4F7F6), NSColor(hex: 0xE9F0F4)]
    static let ruCeladonLight: [NSColor] = [NSColor(hex: 0xB9D2CC), NSColor(hex: 0xE3EDE9)]
    static let ruCeladonDark: [NSColor] = [NSColor(hex: 0x1F2A28), NSColor(hex: 0x2A3834)]
    static let inkPaper: [NSColor] = [NSColor(hex: 0xF5F1E8), NSColor(hex: 0xEFEAE0)]
}

// MARK: - 主题定义

public extension Theme {

    /// Glass —— 默认主题：macOS Liquid Glass 语言。深墨沉入系统色，
    /// 逐页在 systemBlue / systemIndigo / systemTeal / systemPurple 间流转。
    static let glass = Theme(id: "glass", name: "Glass", tagline: "macOS Liquid Glass",
                             kind: "现代") { index, total, mode in
        let accent = GlassPalette.accents[index % GlassPalette.accents.count]
        let dark = mode == .dark
        // Light mode keeps REAL hue: airy pastel gradients (Mac Blue /
        // Mac Purple light wallpapers), not desaturated grey.
        let bg = dark
            ? GlassPalette.gradients[index % GlassPalette.gradients.count]
            : GlassPalette.gradientsLight[index % GlassPalette.gradientsLight.count]
        return SlideStyle(
            background: bg,
            textColor: dark ? NSColor(hex: 0xF2F4F8) : GlassPalette.inkLight,
            headlineColor: dark ? .white : GlassPalette.inkLight,
            kickerColor: accent,
            accent: accent,
            pageColor: dark ? NSColor(hex: 0x8E8E93) : GlassPalette.pageLight,
            headlineFamily: Typography.resolvedFamily("inter"),
            headlineWeight: .bold,
            headlineScale: 1.1,
            uppercaseKicker: true,
            centerContent: false,
            useHairlineDivider: false
        )
    }

    /// 敦煌 —— 矿物颜料，壁上千年。饱和而内敛的「多巴胺」。
    static let dunhuang = Theme(id: "dunhuang", name: "敦煌 Dunhuang", tagline: "矿物颜料 · 壁上千年",
                                kind: "画彩") { index, total, mode in
        let base = Palette.dunhuang[index % Palette.dunhuang.count]
        let bg = mode == .dark ? base.mixed(with: .black, t: 0.5) : base
        let text = bg.contrastingText
        return SlideStyle(
            background: [bg],
            textColor: text,
            headlineColor: text,
            kickerColor: text.withAlpha(0.72),
            accent: text,
            pageColor: text.withAlpha(0.6),
            headlineFamily: Typography.resolvedFamily("inter"),
            headlineWeight: .heavy,
            headlineScale: 1.12,
            uppercaseKicker: true,
            centerContent: false,
            useHairlineDivider: false
        )
    }

    /// 故宫 —— 宫墙红与琉璃金交替，庄重而热烈。
    static let gugong = Theme(id: "gugong", name: "故宫 Forbidden City", tagline: "宫墙红 · 琉璃金",
                              kind: "宫苑") { index, total, mode in
        let dark = mode == .dark
        let onGold = index % 2 == 0
        let bg: NSColor
        let text: NSColor
        let accent: NSColor
        if onGold {
            bg = dark ? NSColor(hex: 0x8A6B3A) : Palette.gugongGold
            text = dark ? NSColor(hex: 0xF5EBD6) : NSColor(hex: 0x3B2A1A)
            accent = Palette.gugongRed
        } else {
            bg = dark ? NSColor(hex: 0x661B16) : Palette.gugongRed
            text = NSColor(hex: 0xF5F2EA)
            accent = Palette.gugongGold
        }
        return SlideStyle(
            background: [bg],
            textColor: text,
            headlineColor: text,
            kickerColor: accent,
            accent: accent,
            pageColor: text.withAlpha(0.6),
            headlineFamily: Typography.resolvedFamily("songti"),
            headlineWeight: .semibold,
            headlineScale: 1.08,
            uppercaseKicker: false,
            centerContent: false,
            useHairlineDivider: true
        )
    }

    /// 青花 —— 钴蓝与瓷白交替，素净典雅。
    static let qinghua = Theme(id: "qinghua", name: "青花 Blue & White", tagline: "钴蓝白瓷",
                               kind: "瓷器") { index, total, mode in
        let dark = mode == .dark
        let onPorcelain = index % 2 == 0
        let bg: [NSColor]
        let text: NSColor
        if onPorcelain {
            bg = dark ? [NSColor(hex: 0x141A24)] : Palette.porcelainLight
            text = dark ? NSColor(hex: 0x9FC0E8) : Palette.qinghuaCobalt
        } else {
            bg = [dark ? NSColor(hex: 0x123058) : Palette.qinghuaCobalt]
            text = NSColor(hex: 0xF2F6F8)
        }
        return SlideStyle(
            background: bg,
            textColor: text,
            headlineColor: text,
            kickerColor: Palette.qinghuaCobalt.mixed(with: NSColor(hex: 0xF2F6F8), t: 0.45),
            accent: Palette.qinghuaCobalt,
            pageColor: text.withAlpha(0.6),
            headlineFamily: Typography.resolvedFamily("songti"),
            headlineWeight: .regular,
            headlineScale: 1.0,
            uppercaseKicker: false,
            centerContent: false,
            useHairlineDivider: true
        )
    }

    /// 汝窑 —— 「雨过天青云破处」。天青渐变、大量留白、内容居中。
    static let ru = Theme(id: "ru", name: "汝窑 Ru Kiln", tagline: "雨过天青云破处",
                          kind: "极简") { index, total, mode in
        let dark = mode == .dark
        let bg = dark ? Palette.ruCeladonDark : Palette.ruCeladonLight
        let text = dark ? NSColor(hex: 0xD6E2DE) : NSColor(hex: 0x2E3A38)
        let accent = dark ? NSColor(hex: 0x8FB4AE) : NSColor(hex: 0x7FA6A0)
        return SlideStyle(
            background: bg,
            textColor: text,
            headlineColor: text,
            kickerColor: accent,
            accent: accent,
            pageColor: text.withAlpha(0.55),
            headlineFamily: Typography.resolvedFamily("songti"),
            headlineWeight: .regular,
            headlineScale: 0.95,
            uppercaseKicker: false,
            centerContent: true,
            useHairlineDivider: false
        )
    }

    /// 水墨 —— 墨分五色，计白当黑。宣纸与松烟，楷体书写。
    static let shuimo = Theme(id: "shuimo", name: "水墨 Ink Wash", tagline: "墨分五色 · 计白当黑",
                              kind: "极简") { index, total, mode in
        let dark = mode == .dark
        let bg = dark ? [NSColor(hex: 0x17181A)] : Palette.inkPaper
        let text = dark ? NSColor(hex: 0xC9CDD3) : NSColor(hex: 0x2B2B2B)
        let accent = dark ? NSColor(hex: 0x8B93A0) : NSColor(hex: 0x50616D)
        return SlideStyle(
            background: bg,
            textColor: text,
            headlineColor: text,
            kickerColor: accent,
            accent: accent,
            pageColor: text.withAlpha(0.5),
            headlineFamily: Typography.resolvedFamily("kaiti"),
            headlineWeight: .regular,
            headlineScale: 1.0,
            uppercaseKicker: false,
            centerContent: true,
            useHairlineDivider: false
        )
    }

    /// 江南 —— 粉墙黛瓦，烟雨粉彩。
    static let jiangnan = Theme(id: "jiangnan", name: "江南 Jiangnan", tagline: "粉墙黛瓦 · 烟雨",
                                kind: "粉彩") { index, total, mode in
        let base = Palette.jiangnan[index % Palette.jiangnan.count]
        let bg = mode == .dark ? base.mixed(with: .black, t: 0.4) : base
        let text = mode == .dark ? NSColor(hex: 0xE8EEF2) : NSColor(hex: 0x33414E)
        return SlideStyle(
            background: [bg],
            textColor: text,
            headlineColor: text,
            kickerColor: text.withAlpha(0.6),
            accent: text,
            pageColor: text.withAlpha(0.55),
            headlineFamily: Typography.resolvedFamily("helvetica"),
            headlineWeight: .regular,
            headlineScale: 0.98,
            uppercaseKicker: false,
            centerContent: false,
            useHairlineDivider: false
        )
    }

    /// 五行 —— 青赤黄白黑，周而复始；天生兼具明暗。
    static let wuxing = Theme(id: "wuxing", name: "五行 Five Elements", tagline: "青赤黄白黑",
                              kind: "系统") { index, total, mode in
        let cycle: [(bg: NSColor, text: NSColor)] = [
            (NSColor(hex: 0x2E7D67), .white),                     // 青 · 木
            (NSColor(hex: 0xC3272B), .white),                     // 赤 · 火
            (NSColor(hex: 0xD9A441), NSColor(hex: 0x3B2A1A)),     // 黄 · 土
            (NSColor(hex: 0xF2EFE9), NSColor(hex: 0x26282B)),     // 白 · 金
            (NSColor(hex: 0x26282B), NSColor(hex: 0xEDEDEA)),     // 黑 · 水
        ]
        let (bg, text) = cycle[index % cycle.count]
        return SlideStyle(
            background: [bg],
            textColor: text,
            headlineColor: text,
            kickerColor: text.withAlpha(0.7),
            accent: text,
            pageColor: text.withAlpha(0.6),
            headlineFamily: Typography.resolvedFamily("inter"),
            headlineWeight: .medium,
            headlineScale: 1.05,
            uppercaseKicker: true,
            centerContent: false,
            useHairlineDivider: false
        )
    }

    /// 茶境 —— 茶汤温润，回甘悠长。
    static let chajing = Theme(id: "chajing", name: "茶境 Tea", tagline: "茶汤温润 · 回甘",
                               kind: "暖色") { index, total, mode in
        let base = Palette.tea[index % Palette.tea.count]
        let bg = mode == .dark ? base.mixed(with: .black, t: 0.42) : base
        let text = bg.isDark ? NSColor(hex: 0xF2E7D8) : NSColor(hex: 0x3E2F23)
        return SlideStyle(
            background: [bg],
            textColor: text,
            headlineColor: text,
            kickerColor: text.withAlpha(0.6),
            accent: text,
            pageColor: text.withAlpha(0.55),
            headlineFamily: Typography.resolvedFamily("songti"),
            headlineWeight: .regular,
            headlineScale: 0.96,
            uppercaseKicker: false,
            centerContent: false,
            useHairlineDivider: true
        )
    }

    /// 竹青 —— 竹影清风，青翠安静。
    static let zhuqing = Theme(id: "zhuqing", name: "竹青 Bamboo", tagline: "竹影清风",
                               kind: "粉彩") { index, total, mode in
        let base = Palette.bamboo[index % Palette.bamboo.count]
        let bg = mode == .dark ? base.mixed(with: .black, t: 0.45) : base
        let text = bg.isDark ? NSColor(hex: 0xEAF2E4) : NSColor(hex: 0x24331F)
        return SlideStyle(
            background: [bg],
            textColor: text,
            headlineColor: text,
            kickerColor: text.withAlpha(0.6),
            accent: text,
            pageColor: text.withAlpha(0.55),
            headlineFamily: Typography.resolvedFamily("helvetica"),
            headlineWeight: .regular,
            headlineScale: 0.98,
            uppercaseKicker: false,
            centerContent: false,
            useHairlineDivider: false
        )
    }
}
