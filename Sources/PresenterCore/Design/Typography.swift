import AppKit
import Foundation

// MARK: - Typography
//
// The real iA Presenter ships with the iA Writer Duo/Quattro/Mono variable
// fonts. We detect those first, then fall back to beautiful system faces.

public enum Typography {

    /// Resolve a font family key to a usable NSFont family name.
    public static func resolvedFamily(_ key: String) -> String {
        switch key.lowercased() {
        case "ia-mono": return iAFontMatching(["iA Writer Mono S", "iA Writer Mono"]) ?? "Menlo"
        case "ia-duo": return iAFontMatching(["iA Writer Duo S", "iA Writer Duo"]) ?? "Avenir Next"
        case "ia-quattro": return iAFontMatching(["iA Writer Quattro S", "iA Writer Quattro"]) ?? "Georgia"
        case "songti": return installedAny(["Songti SC", "STSong", "Noto Serif CJK SC", "Source Han Serif SC"]) ?? "Georgia"
        case "kaiti": return installedAny(["Kaiti SC", "STKaiti", "Kaiti"]) ?? "Songti SC"
        case "inter": return "Helvetica Neue"
        case "noto-serif": return installedAny(["Noto Serif", "Songti SC"]) ?? "Georgia"
        case "montserrat": return "Avenir Next"
        case "helvetica": return "Helvetica Neue"
        case "garamond": return installedAny(["EB Garamond", "Garamond"]) ?? "Georgia"
        case "georgia": return "Georgia"
        case "palatino": return "Palatino"
        case "system-rounded": return "SF Pro Rounded"
        case "menlo": return "Menlo"
        case "system": return "Helvetica Neue"
        default: return key
        }
    }

    public static func iAFontMatching(_ names: [String]) -> String? {
        let families = Set(NSFontManager.shared.availableFontFamilies)
        return names.first { families.contains($0) }
    }

    public static func installedAny(_ names: [String]) -> String? {
        let families = Set(NSFontManager.shared.availableFontFamilies)
        return names.first { families.contains($0) }
    }

    /// Are the iA Writer fonts installed on this machine?
    public static var hasIAFonts: Bool { iAFontMatching(["iA Writer Mono S", "iA Writer Mono"]) != nil }

    public static func font(family: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if family == "SF Pro Rounded" {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        // Family-name based lookup via descriptor: robust for CJK faces like
        // "Songti SC" / "Kaiti SC", which NSFont(name:) cannot resolve.
        let families = Set(NSFontManager.shared.availableFontFamilies)
        if families.contains(family) {
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: family,
                .traits: [NSFontDescriptor.TraitKey.weight: weight],
            ])
            if let font = NSFont(descriptor: descriptor, size: size) {
                return font
            }
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// Curated list of headline font choices shown in the Design inspector.
    public static var headlineChoices: [(key: String, label: String)] {
        var choices: [(String, String)] = [
            ("songti", "宋体 Songti SC"),
            ("kaiti", "楷体 Kaiti SC"),
            ("inter", "Inter — System Sans"),
            ("helvetica", "Helvetica Neue"),
            ("georgia", "Georgia Serif"),
            ("palatino", "Palatino"),
            ("noto-serif", "Noto Serif"),
            ("garamond", "Garamond"),
            ("montserrat", "Montserrat Alt"),
            ("system-rounded", "SF Rounded"),
            ("menlo", "Menlo Mono"),
        ]
        if hasIAFonts {
            choices.insert(("ia-quattro", "iA Writer Quattro"), at: 0)
            choices.insert(("ia-duo", "iA Writer Duo"), at: 1)
        }
        return choices
    }

    /// Editor font: iA Writer Mono when installed, Menlo otherwise.
    public static var editorFamily: String {
        iAFontMatching(["iA Writer Mono S", "iA Writer Mono"]) ?? "Menlo"
    }

    public static var editorFont: NSFont {
        NSFont(name: editorFamily, size: 15)
            ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    }
}
