import Foundation
import QuickLookUI
import UniformTypeIdentifiers
import MarkdownRendererCore

@MainActor
final class PreviewProvider: QLPreviewProvider {
    private let renderer = MarkdownRenderer()

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let rendered = try renderer.renderDocument(fileURL: request.fileURL)
        let html = rendered.html

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")

        try Data(html.utf8).write(to: temporaryURL, options: .atomic)

        let reply = QLPreviewReply(fileURL: temporaryURL)
        reply.title = rendered.metadata.title
        reply.stringEncoding = .utf8
        let metadataText = """
        \(rendered.metadata.title)
        \(rendered.metadata.description)
        \(rendered.metadata.keywords.joined(separator: ", "))
        """
        reply.attachments = [
            "metadata.txt": QLPreviewReplyAttachment(
                data: Data(metadataText.utf8),
                contentType: .plainText
            )
        ]
        return reply
    }
}
