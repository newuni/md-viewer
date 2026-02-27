import Foundation
import Markdown

public enum MarkdownRenderError: LocalizedError {
    case invalidFileURL(URL)
    case unreadableFile(URL, Error)
    case unsupportedEncoding(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidFileURL(url):
            return "The path \(url.path) is not a local file URL."
        case let .unreadableFile(url, error):
            return "Failed to read \(url.lastPathComponent): \(error.localizedDescription)"
        case let .unsupportedEncoding(url):
            return "The file \(url.lastPathComponent) is not valid UTF-8 text."
        }
    }
}

public struct MarkdownRenderer {
    public init() {}

    public func render(markdown: String, title: String = "Markdown Preview") throws -> String {
        let rawHTML = HTMLFormatter.format(markdown)
        let sanitizedHTML = sanitize(html: rawHTML)
        return wrapInDocument(bodyHTML: sanitizedHTML, title: title)
    }

    public func render(fileURL: URL) throws -> String {
        guard fileURL.isFileURL else {
            throw MarkdownRenderError.invalidFileURL(fileURL)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            guard let markdown = String(data: data, encoding: .utf8) else {
                throw MarkdownRenderError.unsupportedEncoding(fileURL)
            }
            return try render(markdown: markdown, title: fileURL.lastPathComponent)
        } catch let error as MarkdownRenderError {
            throw error
        } catch {
            throw MarkdownRenderError.unreadableFile(fileURL, error)
        }
    }

    private func sanitize(html: String) -> String {
        var sanitized = html

        sanitized = sanitized.replacing(
            pattern: #"<script\b[^>]*>[\s\S]*?</script>"#,
            with: "",
            options: [.caseInsensitive]
        )

        sanitized = sanitized.replacing(
            pattern: #"<(iframe|object|embed)\b[^>]*>[\s\S]*?</\1>"#,
            with: "",
            options: [.caseInsensitive]
        )

        sanitized = sanitized.replacing(
            pattern: #"\son\w+\s*=\s*\"[^\"]*\""#,
            with: "",
            options: [.caseInsensitive]
        )

        sanitized = sanitized.replacing(
            pattern: #"\son\w+\s*=\s*'[^']*'"#,
            with: "",
            options: [.caseInsensitive]
        )

        sanitized = sanitized.replacing(
            pattern: #"(href|src)\s*=\s*\"javascript:[^\"]*\""#,
            with: "$1=\"#\"",
            options: [.caseInsensitive]
        )

        sanitized = sanitized.replacing(
            pattern: #"(href|src)\s*=\s*'javascript:[^']*'"#,
            with: "$1='#'",
            options: [.caseInsensitive]
        )

        return sanitized
    }

    private func wrapInDocument(bodyHTML: String, title: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escapeHTML(title))</title>
            <style>
                :root {
                    color-scheme: light dark;
                    --bg: #f8f8f8;
                    --text: #202124;
                    --muted: #5f6368;
                    --code-bg: #eceff1;
                    --border: #dadce0;
                    --link: #0b57d0;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #111315;
                        --text: #e8eaed;
                        --muted: #9aa0a6;
                        --code-bg: #1f2327;
                        --border: #303134;
                        --link: #8ab4f8;
                    }
                }
                html, body {
                    margin: 0;
                    padding: 0;
                    background: var(--bg);
                    color: var(--text);
                    font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                    line-height: 1.55;
                }
                body {
                    max-width: 980px;
                    margin: 0 auto;
                    padding: 28px;
                    box-sizing: border-box;
                }
                h1, h2, h3, h4, h5, h6 {
                    line-height: 1.25;
                    margin-top: 1.2em;
                    margin-bottom: 0.45em;
                }
                p, ul, ol, pre, table, blockquote {
                    margin-top: 0;
                    margin-bottom: 1em;
                }
                a {
                    color: var(--link);
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                code {
                    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                    background: var(--code-bg);
                    border-radius: 6px;
                    padding: 0.15em 0.35em;
                }
                pre {
                    background: var(--code-bg);
                    border: 1px solid var(--border);
                    border-radius: 8px;
                    padding: 12px;
                    overflow-x: auto;
                }
                pre code {
                    background: transparent;
                    padding: 0;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                }
                th, td {
                    border: 1px solid var(--border);
                    padding: 8px;
                    text-align: left;
                }
                th {
                    background: color-mix(in srgb, var(--code-bg) 75%, transparent);
                }
                blockquote {
                    border-left: 3px solid var(--border);
                    padding-left: 12px;
                    color: var(--muted);
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private extension String {
    func replacing(pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return self
        }
        let range = NSRange(location: 0, length: utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
    }
}
