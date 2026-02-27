import XCTest
@testable import MarkdownRendererCore

final class MDViewerAppTests: XCTestCase {
    func testRendererEndToEnd() throws {
        let markdown = "# Hello\n\nThis is a **preview**."
        let html = try MarkdownRenderer().render(markdown: markdown)
        XCTAssertTrue(html.contains("<strong>preview</strong>"))
    }
}
