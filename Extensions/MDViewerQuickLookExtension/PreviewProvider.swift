import Foundation
import QuickLookUI
import MarkdownRendererCore

@MainActor
final class PreviewProvider: QLPreviewProvider {
    private let renderer = MarkdownRenderer()

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let html = try renderer.render(fileURL: request.fileURL)

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")

        try Data(html.utf8).write(to: temporaryURL, options: .atomic)

        let reply = QLPreviewReply(fileURL: temporaryURL)
        reply.title = request.fileURL.lastPathComponent
        reply.stringEncoding = .utf8
        return reply
    }
}
