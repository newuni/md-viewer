import Testing
@testable import MarkdownRendererCore

struct MarkdownRendererCoreTests {
    private let renderer = MarkdownRenderer()

    @Test
    func rendersHeadingsAndLists() throws {
        let markdown = """
        # Title

        - One
        - Two
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li><p>One</p>"))
    }

    @Test
    func rendersCodeFence() throws {
        let markdown = """
        ```swift
        let x = 1
        ```
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<pre><code"))
        #expect(html.contains("let x = 1"))
    }

    @Test
    func rendersTables() throws {
        let markdown = """
        | Name | Value |
        | ---- | ----- |
        | A    | 1     |
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<table>"))
        #expect(html.contains("<td>1</td>"))
    }

    @Test
    func sanitizesScriptTags() throws {
        let markdown = """
        # Hello
        <script>alert('xss')</script>
        """

        let html = try renderer.render(markdown: markdown)

        #expect(!html.localizedCaseInsensitiveContains("<script"))
        #expect(html.contains("<h1>Hello</h1>"))
    }

    @Test
    func handlesEmptyInput() throws {
        let html = try renderer.render(markdown: "")

        #expect(html.contains("<!doctype html>"))
        #expect(html.contains("<body>"))
    }

    @Test
    func supportsUTF8Characters() throws {
        let markdown = "# Cancion\n\nHola, senor. Manana llegara el avion."
        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("Cancion"))
        #expect(html.contains("Manana"))
    }

    @Test
    func largeFileRendering() throws {
        let markdown = String(repeating: "- line\n", count: 170_000)
        #expect(markdown.utf8.count > 1_000_000)

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<ul>"))
        #expect(html.count > 1_000_000)
    }
}
