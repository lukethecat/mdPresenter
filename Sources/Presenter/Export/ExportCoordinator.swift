import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import PresenterCore

// MARK: - File handling & export
//
// Open/save `.presenter` files, import Markdown with TurboStart, and
// export: slides PDF, handout PDF, Markdown, and PNG images.

enum ExportCoordinator {

    // MARK: Open / save

    static func newDocument(_ state: AppState, blank: Bool) {
        state.newDocument(blank: blank)
    }

    static func openDocument(_ state: AppState) {
        let panel = NSOpenPanel()
        // `.presenter` / `.iapresenter` can be either our JSON documents or
        // iA Presenter directory bundles — both are accepted.
        panel.allowedContentTypes = [
            UTType(filenameExtension: "presenter"),
            UTType(filenameExtension: "iapresenter"),
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            UTType.plainText,
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                do {
                    // 1. iA Presenter bundle (a directory with text.md)?
                    if let iaDoc = try IAPresenterImporter.document(from: url) {
                        state.load(document: iaDoc, url: url)
                        return
                    }
                    // 2. Our own JSON `.presenter` document?
                    let data = try Data(contentsOf: url)
                    if url.pathExtension == "presenter",
                       let doc = try? DocumentFile.decode(data) {
                        state.load(document: doc, url: url)
                        return
                    }
                    // 3. Plain markdown / text — TurboStart converts prose.
                    let raw = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                    let markdown: String
                    switch TurboStart.convert(raw) {
                    case .converted(let md): markdown = md
                    case .untouched(let md): markdown = md
                    }
                    state.load(
                        document: DocumentFile(
                            title: url.deletingPathExtension().lastPathComponent,
                            markdown: markdown
                        ),
                        url: nil
                    )
                } catch {
                    presentError("无法打开文稿", error, state)
                }
            }
        }
    }

    static func saveDocument(_ state: AppState, saveAs: Bool = false) {
        let url: URL?
        if saveAs || state.documentURL == nil {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "presenter")].compactMap { $0 }
            panel.nameFieldStringValue = state.documentTitle + ".presenter"
            panel.runModal()
            url = panel.url
        } else {
            url = state.documentURL
        }
        guard let target = url else { return }
        do {
            let doc = state.currentDocument()
            var file = doc
            file.title = target.deletingPathExtension().lastPathComponent
            try file.encoded().write(to: target, options: .atomic)
            state.documentTitle = file.title
            state.documentURL = target
        } catch {
            presentError("无法保存文稿", error, state)
        }
    }

    // MARK: Export

    static func exportSlidesPDF(_ state: AppState) {
        guard !state.deck.contents.isEmpty else { return }
        let ratio = state.settings.aspect.ratio ?? (16.0 / 9.0)
        let pageWidth: CGFloat = 1280
        let pageSize = CGSize(width: pageWidth, height: pageWidth / ratio)

        let pdf = PDFDocument()
        for content in state.deck.contents {
            let style = state.slideStyle(for: content)
            let image = renderSlide(content: content, style: style, state: state, size: pageSize)
            if let page = PDFPage(image: image) {
                page.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
                pdf.insert(page, at: pdf.pageCount)
            }
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = state.documentTitle + ".pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            pdf.write(to: url)
        }
    }

    static func exportHandoutPDF(_ state: AppState) {
        guard !state.deck.contents.isEmpty else { return }
        do {
            let options = HandoutPDFExporter.Options(
                title: state.documentTitle,
                fontFamily: Typography.resolvedFamily("noto-serif")
            )
            let data = try HandoutPDFExporter.export(deck: state.deck, options: options)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.pdf]
            panel.nameFieldStringValue = state.documentTitle + " — 讲义.pdf"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                try? data.write(to: url)
            }
        } catch {
            presentError("无法生成讲义", error, state)
        }
    }

    static func exportMarkdown(_ state: AppState) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.nameFieldStringValue = state.documentTitle + ".md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let markdown = MarkdownExporter.markdown(from: state.currentDocument())
            try? markdown.data(using: .utf8)?.write(to: url)
        }
    }

    /// Export back into the iA Presenter bundle format (text.md + info.json
    /// + assets/) — round-trip compatible with iA's own app.
    static func exportIAPresenter(_ state: AppState) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "iapresenter")].compactMap { $0 }
        panel.nameFieldStringValue = state.documentTitle + ".iapresenter"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try IAPresenterImporter.write(state.currentDocument(), to: url)
            } catch {
                presentError("无法导出 iA Presenter 文件", error, state)
            }
        }
    }

    static func exportSummaryMarkdown(_ state: AppState) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.nameFieldStringValue = state.documentTitle + " — 摘要.md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let summary = MarkdownExporter.summary(from: state.deck, title: state.documentTitle)
            try? summary.data(using: .utf8)?.write(to: url)
        }
    }

    static func exportImages(_ state: AppState) {
        guard !state.deck.contents.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "导出 PNG"
        panel.begin { response in
            guard response == .OK, let dir = panel.url else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let size = CGSize(width: 1920, height: 1080)
                for (i, content) in state.deck.contents.enumerated() {
                    let style = state.slideStyle(for: content)
                    // AppKit views must render on the main thread.
                    let image = DispatchQueue.main.sync {
                        renderSlide(content: content, style: style, state: state, size: size)
                    }
                    guard
                        let tiff = image.tiffRepresentation,
                        let rep = NSBitmapImageRep(data: tiff),
                        let png = rep.representation(using: .png, properties: [:])
                    else { continue }
                    let url = dir.appendingPathComponent(
                        String(format: "slide-%02d.png", i + 1)
                    )
                    try? png.write(to: url)
                }
            }
        }
    }

    // MARK: Rendering slides to bitmaps

    static func renderSlide(
        content: SlideContent,
        style: SlideStyle,
        state: AppState,
        size: CGSize
    ) -> NSImage {
        let root = SlideCanvas(
            content: content,
            style: style,
            settings: state.settings,
            media: state.media
        )
        .frame(width: size.width, height: size.height)
        .environmentObject(state)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.wantsLayer = true
        hosting.layer?.contentsScale = 2
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return NSImage(size: size)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: Errors

    static func presentError(_ title: String, _ error: Error, _ state: AppState) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
