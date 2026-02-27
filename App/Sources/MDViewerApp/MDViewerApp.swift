import SwiftUI

@main
struct MDViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            MarkdownDocumentView(document: file.document, fileURL: file.fileURL)
        }
        .defaultSize(width: 1200, height: 900)
        .windowResizability(.contentMinSize)
    }
}
