import Foundation

// MARK: - Content / presentation separation
//
// The heart of iA Presenter's philosophy:
//   * Headlines        → what the audience sees (slide content)
//   * Body text        → Speaker Notes (Speech), never shown on the slide
//   * Tab ⇥ prefix     → forces a text block onto the slide
//   * Images/tables/code → slide content
// On the very first slide the first headline becomes the Title and the
// second headline becomes the Subtitle.

public enum SlideLayoutKind: String {
    case title        // big title + subtitle (first slide)
    case statement    // one big headline
    case split        // headline + text on one side, media on the other
    case mediaFull    // media dominates, headline as caption
    case grid         // several media blocks
    case table        // table with headline
    case quote        // headline + supporting text
    case columns      // iA multi-column: heading + text pairs side by side
    case empty
}

public struct SlideContent: Equatable {
    public var slide: Slide
    public var index: Int
    public var total: Int
    public var isTitleSlide: Bool
    public var title: Block?          // first slide only
    public var subtitle: Block?       // first slide only
    public var kicker: Block?         // lowest-level heading used as overline
    public var headline: Block?       // main slide headline
    public var onSlide: [Block]       // everything the audience sees
    public var notes: [Block]         // spoken text (speaker notes)
    public var layout: SlideLayoutKind
    public var notesPlain: String { notes.map { $0.plainText }.joined(separator: "\n") }

    /// Progress color position of this slide in the deck (0...1).
    public var progress: Double {
        guard total > 1 else { return 0 }
        return Double(index) / Double(total - 1)
    }
}

public struct ContentResolver {

    public static func resolve(slides: [Slide]) -> [SlideContent] {
        slides.enumerated().map { index, slide in
            resolve(slide: slide, index: index, total: slides.count)
        }
    }

    public static func resolve(slide: Slide, index: Int, total: Int) -> SlideContent {
        let isTitle = index == 0
        var onSlide = slide.onSlideBlocks
        let notes = slide.spokenBlocks

        var title: Block? = nil
        var subtitle: Block? = nil
        var kicker: Block? = nil
        var headline: Block? = nil

        let headings = slide.headings
        // iA multi-column: several headings each followed by tabbed text
        // form side-by-side columns; all headings stay visible.
        let isColumns = !isTitle && isColumnSlide(onSlide: onSlide)

        if isTitle {
            if !headings.isEmpty { title = headings[0] }
            if headings.count > 1 { subtitle = headings[1] }
            // Extra headings on the title slide become speaker notes.
            let kept = [title, subtitle].compactMap { $0 }
            onSlide.removeAll { block in
                block.kind == .heading && !kept.contains(block)
            }
        } else if isColumns {
            headline = nil
            kicker = nil
        } else {
            let h1 = headings.first { $0.level == 1 }
            let h2 = headings.first { $0.level == 2 }
            let h3 = headings.first { $0.level >= 3 }
            headline = h1 ?? h2 ?? h3 ?? headings.first
            kicker = headline != nil && h3 != nil && h3 != headline ? h3 : nil
            if headline == nil && !headings.isEmpty { headline = headings.first }
            // All headings but the chosen headline/kicker become notes.
            let onSlideHeadings = [headline, kicker].compactMap { $0 }
            for h in headings where !onSlideHeadings.contains(h) {
                onSlide.removeAll { $0 == h }
            }
        }

        // Pick the automatic layout.
        let layout = pickLayout(isTitle: isTitle, onSlide: onSlide, headline: headline, title: title, isColumns: isColumns)

        return SlideContent(
            slide: slide,
            index: index,
            total: total,
            isTitleSlide: isTitle,
            title: title,
            subtitle: subtitle,
            kicker: kicker,
            headline: headline,
            onSlide: onSlide,
            notes: notes,
            layout: layout
        )
    }

    /// Two or more headings each followed by tabbed visible text = columns.
    static func isColumnSlide(onSlide: [Block]) -> Bool {
        var headingCount = 0
        var tabbedCount = 0
        var pendingHeading = false
        var pairs = 0
        for block in onSlide {
            switch block.kind {
            case .heading:
                headingCount += 1
                pendingHeading = true
            case .paragraph, .bulletList, .orderedList:
                if block.isTabbedOnSlide {
                    tabbedCount += 1
                    if pendingHeading { pairs += 1 }
                    pendingHeading = false
                }
            default:
                break
            }
        }
        return headingCount >= 2 && tabbedCount >= 2 && pairs >= 2
    }

    static func pickLayout(
        isTitle: Bool,
        onSlide: [Block],
        headline: Block?,
        title: Block?,
        isColumns: Bool
    ) -> SlideLayoutKind {
        if isTitle { return .title }
        let media = onSlide.filter { $0.isMedia }
        let tables = onSlide.filter { $0.kind == .table }
        let textBlocks = onSlide.filter {
            ($0.kind == .paragraph || $0.kind == .bulletList || $0.kind == .orderedList) && $0.isTabbedOnSlide
        }

        if !tables.isEmpty { return .table }
        if media.count >= 2 { return .grid }
        if media.count == 1 {
            if headline != nil && (!textBlocks.isEmpty || !headline!.plainText.isEmpty) {
                return .split
            }
            return .mediaFull
        }
        if isColumns { return .columns }
        if !textBlocks.isEmpty && headline != nil { return .quote }
        if headline != nil { return .statement }
        if onSlide.isEmpty { return .empty }
        return .statement
    }
}
