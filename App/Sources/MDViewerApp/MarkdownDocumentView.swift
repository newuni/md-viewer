import SwiftUI
import MarkdownRendererCore

struct MarkdownDocumentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    @State private var renderedHTML = ""
    @State private var liveText: String?
    @State private var watcher: MarkdownFileWatcher?
    private let renderer = MarkdownRenderer()

    var body: some View {
        Group {
            if renderedHTML.isEmpty {
                ContentUnavailableView(
                    "Rendering Markdown",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Loading preview...")
                )
            } else {
                HTMLWebView(html: renderedHTML)
            }
        }
        .task(id: effectiveMarkdownText) {
            do {
                renderedHTML = try renderer.render(markdown: effectiveMarkdownText)
            } catch {
                renderedHTML = """
                <!doctype html>
                <html><body><h2>Preview error</h2><p>\(error.localizedDescription)</p></body></html>
                """
            }
        }
        .onAppear {
            startWatchingFileIfNeeded()
        }
        .onChange(of: fileURL) { _, _ in
            startWatchingFileIfNeeded()
        }
        .onDisappear {
            watcher?.stop()
            watcher = nil
        }
    }

    private var effectiveMarkdownText: String {
        liveText ?? document.text
    }

    private func startWatchingFileIfNeeded() {
        watcher?.stop()
        watcher = nil

        guard let fileURL else {
            return
        }

        let watcher = MarkdownFileWatcher(fileURL: fileURL) {
            DispatchQueue.main.async {
                reloadFileFromDisk(fileURL)
            }
        }
        self.watcher = watcher
        watcher.start()
    }

    private func reloadFileFromDisk(_ fileURL: URL) {
        guard
            let data = try? Data(contentsOf: fileURL),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        if text != liveText {
            liveText = text
        }
    }
}
