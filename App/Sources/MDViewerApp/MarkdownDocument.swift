import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [
            UTType.mdViewerMarkdown,
            UTType.mdViewerMarkdownAlt,
            .plainText
        ]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            text = ""
            return
        }

        guard let textValue = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        text = textValue
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

private extension UTType {
    static let mdViewerMarkdown = UTType(filenameExtension: "md") ?? .plainText
    static let mdViewerMarkdownAlt = UTType(filenameExtension: "markdown") ?? .plainText
}
