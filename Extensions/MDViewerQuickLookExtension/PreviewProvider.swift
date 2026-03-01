import AppKit
import Foundation
import QuickLookUI
import UniformTypeIdentifiers
import MarkdownRendererCore

@MainActor
final class PreviewProvider: QLPreviewProvider {
    private let renderer = MarkdownRenderer()

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        do {
            let rendered = try renderer.renderNativeDocument(fileURL: request.fileURL)
            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("rtf")

            let rtfData = try rendered.attributedString.data(
                from: NSRange(location: 0, length: rendered.attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try rtfData.write(to: temporaryURL, options: .atomic)
            return makeReply(fileURL: temporaryURL, metadata: rendered.metadata)
        } catch {
            let rendered = try renderer.renderDocument(fileURL: request.fileURL)
            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("html")
            try Data(rendered.html.utf8).write(to: temporaryURL, options: .atomic)
            return makeReply(fileURL: temporaryURL, metadata: rendered.metadata)
        }
    }

    private func makeReply(fileURL: URL, metadata: MarkdownRenderMetadata) -> QLPreviewReply {
        let reply = QLPreviewReply(fileURL: fileURL)
        reply.title = metadata.title
        reply.stringEncoding = .utf8
        let metadataText = """
        \(metadata.title)
        \(metadata.description)
        \(metadata.keywords.joined(separator: ", "))
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
