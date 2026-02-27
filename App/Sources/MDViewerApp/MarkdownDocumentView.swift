import SwiftUI
import MarkdownRendererCore

struct MarkdownDocumentView: View {
    let document: MarkdownDocument

    @State private var renderedHTML = ""
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
        .task(id: document.text) {
            do {
                renderedHTML = try renderer.render(markdown: document.text)
            } catch {
                renderedHTML = """
                <!doctype html>
                <html><body><h2>Preview error</h2><p>\(error.localizedDescription)</p></body></html>
                """
            }
        }
    }
}
