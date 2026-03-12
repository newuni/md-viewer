import Foundation
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

        #expect(html.contains("<h1 id=\"title\">Title</h1>"))
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
        #expect(html.contains("<h1 id=\"hello\">Hello</h1>"))
    }

    @Test
    func handlesEmptyInput() throws {
        let html = try renderer.render(markdown: "")

        #expect(html.contains("<!doctype html>"))
        #expect(html.contains("<body>"))
    }

    @Test
    func rendersFromFileURL() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("md-viewer-tests-\(UUID().uuidString)")
            .appendingPathExtension("md")

        try "# File Title\n\nBody from file.".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let rendered = try renderer.renderDocument(fileURL: fileURL)

        #expect(rendered.metadata.title == "File Title")
        #expect(rendered.html.contains("Body from file."))
    }

    @Test
    func fileURLRendererRejectsNonFileURLs() throws {
        let remoteURL = try #require(URL(string: "https://example.com/readme.md"))

        do {
            _ = try renderer.renderDocument(fileURL: remoteURL)
            #expect(Bool(false), "Expected invalidFileURL error")
        } catch let error as MarkdownRenderError {
            switch error {
            case let .invalidFileURL(url):
                #expect(url == remoteURL)
            default:
                #expect(Bool(false), "Unexpected MarkdownRenderError: \(error.localizedDescription)")
            }
        }
    }

    @Test
    func fileURLRendererRejectsNonUTF8Content() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("md-viewer-tests-bin-\(UUID().uuidString)")
            .appendingPathExtension("md")

        try Data([0xFF, 0xFE, 0x00, 0xD8]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            _ = try renderer.renderDocument(fileURL: fileURL)
            #expect(Bool(false), "Expected unsupportedEncoding error")
        } catch let error as MarkdownRenderError {
            switch error {
            case let .unsupportedEncoding(url):
                #expect(url == fileURL)
            default:
                #expect(Bool(false), "Unexpected MarkdownRenderError: \(error.localizedDescription)")
            }
        }
    }

    @Test
    func supportsUTF8Characters() throws {
        let markdown = "# Cancion\n\nHola, senor. Manana llegara el avion."
        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("Cancion"))
        #expect(html.contains("Manana"))
    }

    @Test
    func generatesHeadingAnchorsForTOCLinks() throws {
        let markdown = """
        ## Indice

        1. [Requisitos previos](#requisitos-previos)

        ## Requisitos previos
        ## Requisitos previos
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("href=\"#requisitos-previos\""))
        #expect(html.contains("<h2 id=\"requisitos-previos\">Requisitos previos</h2>"))
        #expect(html.contains("<h2 id=\"requisitos-previos-2\">Requisitos previos</h2>"))
    }

    @Test
    func largeFileRendering() throws {
        let markdown = String(repeating: "- line\n", count: 170_000)
        #expect(markdown.utf8.count > 1_000_000)

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<ul>"))
        #expect(html.count > 1_000_000)
    }

    @Test
    func highlightsSwiftCodeBlocks() throws {
        let markdown = """
        ```swift
        let total = 42
        // note
        if total > 10 { return }
        ```
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("class=\"tok-keyword\">let</span>"))
        #expect(html.contains("class=\"tok-number\">42</span>"))
        #expect(html.contains("class=\"tok-comment\">// note</span>"))
    }

    @Test
    func rendersMermaidFencesAsHTMLDiagrams() throws {
        let markdown = """
        ```mermaid
        graph TD
            Start --> Stop
        ```
        """

        let rendered = try renderer.renderDocument(markdown: markdown)

        #expect(rendered.html.contains("<pre class=\"mermaid\">"))
        #expect(rendered.html.contains("graph TD"))
        #expect(rendered.html.contains("Start --&gt; Stop"))
        #expect(rendered.html.contains("import mermaid from \"https://cdn.jsdelivr.net/npm/mermaid@11.13.0/dist/mermaid.esm.min.mjs\""))
    }

    @Test
    func includesDocumentMetadataTags() throws {
        let markdown = """
        # Build release docs

        This markdown file describes release automation.
        """

        let rendered = try renderer.renderDocument(markdown: markdown, title: "fallback.md")

        #expect(rendered.metadata.title == "Build release docs")
        #expect(rendered.metadata.description.contains("release automation"))
        #expect(rendered.headings.contains(where: { $0.level == 1 && $0.anchor == "build-release-docs" }))
        #expect(rendered.html.contains("<meta name=\"description\""))
        #expect(rendered.html.contains("<meta name=\"keywords\""))
    }

    @Test
    func canDisableTOCExtractionWhileKeepingAnchors() throws {
        let markdown = """
        ## Section one
        """

        let rendered = try renderer.renderDocument(
            markdown: markdown,
            options: MarkdownRenderOptions(tocExtractionEnabled: false)
        )

        #expect(rendered.headings.isEmpty)
        #expect(rendered.html.contains("<h2 id=\"section-one\">Section one</h2>"))
    }

    @Test
    func fastModeDisablesHighlightAndTOC() throws {
        let markdown = """
        ## Heading

        ```swift
        let total = 42
        ```
        """

        let rendered = try renderer.renderDocument(
            markdown: markdown,
            options: MarkdownRenderOptions(
                syntaxHighlightingEnabled: true,
                tocExtractionEnabled: true,
                fastMode: true
            )
        )

        #expect(rendered.headings.isEmpty)
        #expect(!rendered.html.contains("class=\"tok-keyword\">"))
        #expect(rendered.html.contains("<h2 id=\"heading\">Heading</h2>"))
    }

    @Test
    func stripsFrontMatterFromRenderedBodyAndUsesItAsMetadata() throws {
        let markdown = """
        ---
        title: Real title from front matter
        description: Custom metadata description
        tags: [docs, api]
        ---

        # Body heading

        Content body.
        """

        let rendered = try renderer.renderDocument(markdown: markdown, title: "fallback.md")

        #expect(rendered.metadata.title == "Real title from front matter")
        #expect(rendered.metadata.description == "Custom metadata description")
        #expect(rendered.metadata.keywords == ["docs", "api"])
        #expect(!rendered.html.contains("title: Real title from front matter"))
        #expect(rendered.html.contains("<h1 id=\"body-heading\">Body heading</h1>"))
    }

    @Test
    func supportsCoreGitHubFlavoredMarkdownConstructs() throws {
        let markdown = """
        - [ ] Pending
        - [x] Done

        ~~strikethrough~~

        | Col A | Col B |
        | ----- | ----- |
        | 1     | 2     |
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("type=\"checkbox\""))
        #expect(html.contains("<del>strikethrough</del>"))
        #expect(html.contains("<table>"))
    }

    @Test
    func autolinksPlainURLs() throws {
        let markdown = "Visit https://example.com/docs for details."

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<a href=\"https://example.com/docs\">https://example.com/docs</a>"))
    }

    @Test
    func autolinkKeepsTrailingPunctuationOutsideAnchor() throws {
        let markdown = "See https://example.com/docs, then continue."

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<a href=\"https://example.com/docs\">https://example.com/docs</a>, then continue."))
    }

    @Test
    func autolinkSkipsURLsInCodeAndExistingLinks() throws {
        let markdown = """
        Use `https://example.com/inline` inside code.

        [Existing](https://example.com/already-linked)

        ```
        https://example.com/fenced
        ```
        """

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("<code>https://example.com/inline</code>"))
        #expect(html.contains("href=\"https://example.com/already-linked\""))
        #expect(!html.contains("href=\"<a href=\""))
        #expect(html.contains("<pre><code>https://example.com/fenced"))
    }

    @Test
    func sanitizesJavaScriptLinksAndInlineEventHandlers() throws {
        let markdown = #"""
        <a href="javascript:alert('x')" onclick="evil()">click</a>
        <img src='javascript:alert(1)' onerror='evil()'>
        """#

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("href=\"#\""))
        #expect(html.contains("src='#'"))
        #expect(!html.localizedCaseInsensitiveContains("onclick="))
        #expect(!html.localizedCaseInsensitiveContains("onerror="))
    }

    @Test
    func autolinkExcludesTrailingParentheses() throws {
        let markdown = "See (https://example.com/path)."

        let html = try renderer.render(markdown: markdown)

        #expect(html.contains("(<a href=\"https://example.com/path\">https://example.com/path</a>)."))
    }

    @Test
    func preservesExistingHeadingIDs() throws {
        let markdown = #"""
        <h2 id="custom-anchor">Section</h2>
        """#

        let rendered = try renderer.renderDocument(markdown: markdown)

        #expect(rendered.html.contains("<h2 id=\"custom-anchor\">Section</h2>"))
        #expect(rendered.headings.contains(where: { $0.anchor == "custom-anchor" }))
    }

    @Test
    func frontMatterSupportsFoldedDescriptionLines() throws {
        let markdown = """
        ---
        title: Release Notes
        description: First line
          second line
        keywords: swift, markdown
        ---

        Body section.
        """

        let rendered = try renderer.renderDocument(markdown: markdown)

        #expect(rendered.metadata.title == "Release Notes")
        #expect(rendered.metadata.description == "First line second line")
        #expect(rendered.metadata.keywords.contains("swift"))
        #expect(rendered.metadata.keywords.contains("markdown"))
    }

    @Test
    func fileURLRendererWrapsUnreadablePathErrors() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("md-viewer-missing-\(UUID().uuidString).md")

        do {
            _ = try renderer.renderDocument(fileURL: missing)
            #expect(Bool(false), "Expected unreadableFile error")
        } catch let error as MarkdownRenderError {
            switch error {
            case let .unreadableFile(url, underlying):
                #expect(url == missing)
                #expect(!underlying.localizedDescription.isEmpty)
            default:
                #expect(Bool(false), "Unexpected MarkdownRenderError: \(error.localizedDescription)")
            }
        }
    }

#if canImport(AppKit)
    @Test
    func nativeRenderProducesAttributedStringAndHeadingOffsets() throws {
        let markdown = """
        # Intro

        Paragraph body.

        ## Details

        More text.
        """

        let rendered = try renderer.renderNativeDocument(markdown: markdown)

        #expect(rendered.attributedString.length > 0)
        #expect(rendered.attributedString.string.contains("Paragraph body."))
        #expect(rendered.headings.count == 2)
        #expect(rendered.headings[0].anchor == "intro")
        #expect((rendered.headings[0].characterOffset ?? -1) >= 0)
        #expect((rendered.headings[1].characterOffset ?? -1) >= 0)
    }

    @Test
    func nativeFastModeDisablesTOCExtraction() throws {
        let markdown = """
        ## Section one
        """

        let rendered = try renderer.renderNativeDocument(
            markdown: markdown,
            options: MarkdownRenderOptions(
                syntaxHighlightingEnabled: true,
                tocExtractionEnabled: true,
                fastMode: true
            )
        )

        #expect(rendered.headings.isEmpty)
    }

    @Test
    func nativeRenderDoesNotExposeSearchableShadowText() throws {
        let token = "UNIQUE_NATIVE_SHADOW_TOKEN"
        let markdown = """
        # Heading

        Body \(token)
        """

        let rendered = try renderer.renderNativeDocument(markdown: markdown)
        let occurrences = rendered.attributedString.string.components(separatedBy: token).count - 1

        #expect(occurrences == 1)
    }

    @Test
    func nativeRenderAddsBreathingRoomBeforeHeadings() throws {
        let markdown = """
        Intro line
        ## Heading
        """

        let rendered = try renderer.renderNativeDocument(markdown: markdown)
        let text = rendered.attributedString.string
        guard let headingRange = text.range(of: "Heading") else {
            #expect(Bool(false))
            return
        }

        let prefix = String(text[..<headingRange.lowerBound])
        #expect(prefix.hasSuffix("\n\n"))
    }

    @Test
    func nativeRenderRejectsMermaidDiagrams() throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        do {
            _ = try renderer.renderNativeDocument(markdown: markdown)
            #expect(Bool(false), "Expected requiresHTMLPresentation error")
        } catch let error as MarkdownRenderError {
            switch error {
            case let .requiresHTMLPresentation(reason):
                #expect(reason.contains("Mermaid"))
            default:
                #expect(Bool(false), "Unexpected MarkdownRenderError: \(error.localizedDescription)")
            }
        }
    }
#endif
}
