import Foundation

// MARK: - Speech timing
//
// The editor shows a live estimate of how long the talk will take, based
// on the narrative (speaker notes). Latin text ≈ 150 words/minute,
// CJK text ≈ 240 characters/minute.

public struct SpeechTimer {

    public static func estimatedMinutes(notes: String) -> Double {
        let cjk = notes.filter { ch in
            ch.unicodeScalars.first.map { $0.value > 0x2E80 && $0.value < 0x9FFF || $0.value >= 0xF900 } ?? false
        }
        let latinWords = notes.split { $0.isWhitespace }.count - notes.split { $0.isWhitespace }.filter { word in
            word.allSatisfy { ch in ch.unicodeScalars.first.map { $0.value > 0x2E80 && $0.value < 0x9FFF || $0.value >= 0xF900 } ?? false }
        }.count
        let cjkMinutes = Double(cjk.count) / 240.0
        let latinMinutes = Double(max(0, latinWords)) / 150.0
        return cjkMinutes + latinMinutes
    }

    public static func estimatedMinutes(slides: [SlideContent]) -> Double {
        slides.reduce(0) { $0 + estimatedMinutes(notes: $1.notesPlain) }
    }

    public static func estimatedMinutes(slide: SlideContent) -> Double {
        estimatedMinutes(notes: slide.notesPlain)
    }

    /// Human readable estimate, e.g. "≈ 12 min" or "≈ 45 s".
    public static func label(minutes: Double) -> String {
        if minutes < 0.75 {
            let seconds = Int((minutes * 60).rounded())
            return "≈ \(seconds) s"
        }
        return String(format: "≈ %.0f min", minutes.rounded())
    }

    public static func clock(minutes: Double) -> String {
        let total = max(0, Int(minutes * 60))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
