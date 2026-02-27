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

public struct MarkdownRenderMetadata: Equatable {
    public let title: String
    public let description: String
    public let keywords: [String]
    public let searchableText: String

    public init(title: String, description: String, keywords: [String], searchableText: String) {
        self.title = title
        self.description = description
        self.keywords = keywords
        self.searchableText = searchableText
    }
}

public struct MarkdownRenderOptions: Equatable, Sendable {
    public var syntaxHighlightingEnabled: Bool
    public var tocExtractionEnabled: Bool
    public var fastMode: Bool

    public init(
        syntaxHighlightingEnabled: Bool = true,
        tocExtractionEnabled: Bool = true,
        fastMode: Bool = false
    ) {
        self.syntaxHighlightingEnabled = syntaxHighlightingEnabled
        self.tocExtractionEnabled = tocExtractionEnabled
        self.fastMode = fastMode
    }
}

public struct HeadingItem: Equatable, Sendable {
    public let level: Int
    public let text: String
    public let anchor: String

    public init(level: Int, text: String, anchor: String) {
        self.level = level
        self.text = text
        self.anchor = anchor
    }
}

public struct RenderedMarkdownDocument: Equatable {
    public let html: String
    public let metadata: MarkdownRenderMetadata
    public let headings: [HeadingItem]

    public init(html: String, metadata: MarkdownRenderMetadata, headings: [HeadingItem] = []) {
        self.html = html
        self.metadata = metadata
        self.headings = headings
    }
}

public struct MarkdownRenderer {
    public init() {}

    public func render(
        markdown: String,
        title: String = "Markdown Preview",
        options: MarkdownRenderOptions = MarkdownRenderOptions()
    ) throws -> String {
        try renderDocument(markdown: markdown, title: title, options: options).html
    }

    public func renderDocument(
        markdown: String,
        title: String = "Markdown Preview",
        options: MarkdownRenderOptions = MarkdownRenderOptions()
    ) throws -> RenderedMarkdownDocument {
        let normalizedOptions = normalizedOptions(for: options)
        let preprocessed = preprocessMarkdown(markdown)
        let rawHTML = HTMLFormatter.format(preprocessed.bodyMarkdown)
        let sanitizedHTML = sanitize(html: rawHTML)
        let anchored = addHeadingAnchors(
            html: sanitizedHTML,
            collectTOC: normalizedOptions.tocExtractionEnabled
        )
        let htmlWithHeadingAnchors = anchored.html
        let highlightedHTML = normalizedOptions.syntaxHighlightingEnabled
            ? highlightCodeBlocks(html: htmlWithHeadingAnchors)
            : htmlWithHeadingAnchors
        let autolinkedHTML = addAutolinks(to: highlightedHTML)
        let metadata = buildMetadata(
            fromBodyHTML: autolinkedHTML,
            fallbackTitle: title,
            frontMatter: preprocessed.frontMatter
        )
        let finalHTML = wrapInDocument(bodyHTML: autolinkedHTML, metadata: metadata)
        return RenderedMarkdownDocument(
            html: finalHTML,
            metadata: metadata,
            headings: anchored.headings
        )
    }

    public func render(
        fileURL: URL,
        options: MarkdownRenderOptions = MarkdownRenderOptions()
    ) throws -> String {
        try renderDocument(fileURL: fileURL, options: options).html
    }

    public func renderDocument(
        fileURL: URL,
        options: MarkdownRenderOptions = MarkdownRenderOptions()
    ) throws -> RenderedMarkdownDocument {
        guard fileURL.isFileURL else {
            throw MarkdownRenderError.invalidFileURL(fileURL)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            guard let markdown = String(data: data, encoding: .utf8) else {
                throw MarkdownRenderError.unsupportedEncoding(fileURL)
            }
            return try renderDocument(
                markdown: markdown,
                title: fileURL.lastPathComponent,
                options: options
            )
        } catch let error as MarkdownRenderError {
            throw error
        } catch {
            throw MarkdownRenderError.unreadableFile(fileURL, error)
        }
    }

    private func normalizedOptions(for options: MarkdownRenderOptions) -> MarkdownRenderOptions {
        guard options.fastMode else {
            return options
        }

        return MarkdownRenderOptions(
            syntaxHighlightingEnabled: false,
            tocExtractionEnabled: false,
            fastMode: true
        )
    }

    private func preprocessMarkdown(_ markdown: String) -> (bodyMarkdown: String, frontMatter: [String: String]) {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard let firstLine = lines.first else {
            return (markdown, [:])
        }

        guard firstLine.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return (markdown, [:])
        }

        var closingIndex: Int?
        for index in 1..<lines.count {
            let line = String(lines[index]).trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "---" || line == "..." {
                closingIndex = index
                break
            }
        }

        guard let closingIndex else {
            return (markdown, [:])
        }

        let frontMatterLines = lines[1..<closingIndex].map(String.init)
        let parsedFrontMatter = parseFrontMatter(lines: frontMatterLines)

        let remaining = lines[(closingIndex + 1)...].map(String.init).joined(separator: "\n")
        return (remaining, parsedFrontMatter)
    }

    private func parseFrontMatter(lines: [String]) -> [String: String] {
        var result: [String: String] = [:]
        var currentKey: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            if rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t"), let currentKey {
                let extraValue = line
                if !extraValue.isEmpty {
                    let existing = result[currentKey] ?? ""
                    result[currentKey] = existing.isEmpty ? extraValue : "\(existing) \(extraValue)"
                }
                continue
            }

            guard let separatorIndex = line.firstIndex(of: ":") else {
                continue
            }

            let rawKey = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = rawKey.lowercased()
            var value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }

            if value.hasPrefix("["), value.hasSuffix("]"), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            }

            result[key] = value
            currentKey = key
        }

        return result
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

    private func addHeadingAnchors(html: String, collectTOC: Bool) -> (html: String, headings: [HeadingItem]) {
        guard let regex = try? NSRegularExpression(
            pattern: #"<h([1-6])([^>]*)>([\s\S]*?)</h\1>"#,
            options: [.caseInsensitive]
        ) else {
            return (html, [])
        }

        let nsHTML = html as NSString
        let range = NSRange(location: 0, length: nsHTML.length)
        let matches = regex.matches(in: html, options: [], range: range)

        let output = NSMutableString(string: html)
        var offset = 0
        var slugCounts: [String: Int] = [:]
        var headings: [HeadingItem] = []

        for match in matches {
            guard
                match.numberOfRanges == 4,
                let levelRange = Range(match.range(at: 1), in: html),
                let attrsRange = Range(match.range(at: 2), in: html),
                let innerRange = Range(match.range(at: 3), in: html)
            else {
                continue
            }

            let level = String(html[levelRange])
            let attributes = String(html[attrsRange])
            let innerHTML = String(html[innerRange])
            let levelNumber = Int(level) ?? 1

            let plainText = innerHTML
                .replacing(pattern: #"<[^>]+>"#, with: "")
                .decodeBasicHTMLEntities()
                .collapsingWhitespace()

            let existingID = attributes.firstMatch(
                pattern: #"\bid\s*=\s*\"([^\"]+)\""#,
                options: [.caseInsensitive]
            ) ?? attributes.firstMatch(
                pattern: #"\bid\s*=\s*'([^']+)'"#,
                options: [.caseInsensitive]
            )

            let anchor: String
            let replacement: String?
            if let existingID {
                anchor = existingID
                replacement = nil
            } else {
                let baseSlug = slugifyHeading(plainText)
                let count = (slugCounts[baseSlug] ?? 0) + 1
                slugCounts[baseSlug] = count

                let uniqueSlug = count == 1 ? baseSlug : "\(baseSlug)-\(count)"
                anchor = uniqueSlug
                replacement = "<h\(level)\(attributes) id=\"\(uniqueSlug)\">\(innerHTML)</h\(level)>"
            }

            if collectTOC, !plainText.isEmpty {
                headings.append(HeadingItem(level: levelNumber, text: plainText, anchor: anchor))
            }

            if let replacement {
                let adjustedRange = NSRange(
                    location: match.range.location + offset,
                    length: match.range.length
                )
                output.replaceCharacters(in: adjustedRange, with: replacement)
                offset += (replacement as NSString).length - match.range.length
            }
        }

        return (output as String, headings)
    }

    private func highlightCodeBlocks(html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<pre><code(?:\s+class=\"([^\"]*)\")?>([\s\S]*?)</code></pre>"#,
            options: [.caseInsensitive]
        ) else {
            return html
        }

        let nsHTML = html as NSString
        let range = NSRange(location: 0, length: nsHTML.length)
        let matches = regex.matches(in: html, options: [], range: range)

        let output = NSMutableString(string: html)
        var offset = 0

        for match in matches {
            guard match.numberOfRanges == 3 else {
                continue
            }

            let classString: String
            if let classRange = Range(match.range(at: 1), in: html), match.range(at: 1).location != NSNotFound {
                classString = String(html[classRange])
            } else {
                classString = ""
            }

            guard let codeRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let codeHTML = String(html[codeRange])
            let language = codeLanguage(fromClass: classString)
            let highlighted = highlightCodeHTML(codeHTML, language: language)

            let classAttribute = classString.isEmpty ? "" : " class=\"\(classString)\""
            let replacement = "<pre><code\(classAttribute)>\(highlighted)</code></pre>"

            let adjustedRange = NSRange(
                location: match.range.location + offset,
                length: match.range.length
            )
            output.replaceCharacters(in: adjustedRange, with: replacement)
            offset += (replacement as NSString).length - match.range.length
        }

        return output as String
    }

    private func addAutolinks(to html: String) -> String {
        var result = ""
        var index = html.startIndex
        var protectedDepthByTag: [String: Int] = [:]

        while index < html.endIndex {
            if html[index] == "<" {
                guard let tagEnd = html[index...].firstIndex(of: ">") else {
                    result.append(contentsOf: html[index...])
                    break
                }

                let tagText = String(html[index...tagEnd])
                result += tagText
                updateProtectedTagDepths(withTag: tagText, depths: &protectedDepthByTag)
                index = html.index(after: tagEnd)
                continue
            }

            let textEnd = html[index...].firstIndex(of: "<") ?? html.endIndex
            let textChunk = String(html[index..<textEnd])

            if isInsideProtectedTag(protectedDepthByTag) {
                result += textChunk
            } else {
                result += linkifyPlainURLs(in: textChunk)
            }
            index = textEnd
        }

        return result
    }

    private func isInsideProtectedTag(_ depths: [String: Int]) -> Bool {
        (depths["code"] ?? 0) > 0 || (depths["pre"] ?? 0) > 0 || (depths["a"] ?? 0) > 0
    }

    private func updateProtectedTagDepths(withTag tagText: String, depths: inout [String: Int]) {
        guard tagText.hasPrefix("<"), tagText.hasSuffix(">") else {
            return
        }

        let core = tagText.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !core.isEmpty else {
            return
        }
        guard !core.hasPrefix("!") && !core.hasPrefix("?") else {
            return
        }

        var isClosing = false
        var nameStart = core.startIndex
        if core.hasPrefix("/") {
            isClosing = true
            nameStart = core.index(after: core.startIndex)
        }

        let nameEnd = core[nameStart...].firstIndex(where: { $0.isWhitespace || $0 == "/" }) ?? core.endIndex
        let tagName = core[nameStart..<nameEnd].lowercased()
        guard tagName == "code" || tagName == "pre" || tagName == "a" else {
            return
        }

        let isSelfClosing = core.hasSuffix("/")
        if isSelfClosing {
            return
        }

        if isClosing {
            let current = depths[tagName] ?? 0
            depths[tagName] = max(0, current - 1)
        } else {
            depths[tagName] = (depths[tagName] ?? 0) + 1
        }
    }

    private func linkifyPlainURLs(in text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)\bhttps?://[^\s<]+"#
        ) else {
            return text
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else {
            return text
        }

        var output = text
        for match in matches.reversed() {
            let rawURL = nsText.substring(with: match.range)
            let split = splitURLAndTrailingPunctuation(rawURL)
            guard !split.url.isEmpty else {
                continue
            }

            let linked = "<a href=\"\(split.url)\">\(split.url)</a>\(split.trailing)"
            let outputRange = Range(match.range, in: output)!
            output.replaceSubrange(outputRange, with: linked)
        }
        return output
    }

    private func splitURLAndTrailingPunctuation(_ input: String) -> (url: String, trailing: String) {
        let trailingCharset = CharacterSet(charactersIn: ".,;:!?)]}")
        var trimmed = input
        var trailing = ""

        while let last = trimmed.unicodeScalars.last, trailingCharset.contains(last) {
            trailing = String(last) + trailing
            trimmed.removeLast()
        }

        return (trimmed, trailing)
    }

    private func codeLanguage(fromClass classString: String) -> String? {
        guard let match = classString.firstMatch(pattern: #"language-([a-zA-Z0-9_+-]+)"#) else {
            return nil
        }
        return match.lowercased()
    }

    private func highlightCodeHTML(_ codeHTML: String, language: String?) -> String {
        guard let language, !language.isEmpty else {
            return codeHTML
        }

        var working = codeHTML
        var placeholders: [String: String] = [:]

        func stash(pattern: String, tokenClass: String, options: NSRegularExpression.Options = []) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                return
            }

            let fullRange = NSRange(location: 0, length: (working as NSString).length)
            let matches = regex.matches(in: working, options: [], range: fullRange)

            for match in matches.reversed() {
                let nsWorking = working as NSString
                let rawToken = nsWorking.substring(with: match.range)
                var lettersOnly = UUID().uuidString.lowercased().filter { $0.isLetter }
                if lettersOnly.isEmpty {
                    lettersOnly = "mdvtoken"
                }
                var placeholder = "__MDV_TOKEN_\(lettersOnly)__"
                while placeholders[placeholder] != nil {
                    placeholder.append("x")
                }
                placeholders[placeholder] = "<span class=\"\(tokenClass)\">\(rawToken)</span>"
                working = nsWorking.replacingCharacters(in: match.range, with: placeholder)
            }
        }

        let lineCommentPattern: String
        switch language {
        case "swift", "javascript", "js", "typescript", "ts", "java", "c", "cpp", "rust", "go", "kotlin":
            lineCommentPattern = #"//[^\n\r]*"#
            stash(pattern: #"/\*[\s\S]*?\*/"#, tokenClass: "tok-comment")
        case "python", "py", "ruby", "rb", "yaml", "yml", "shell", "bash", "zsh", "sh", "toml":
            lineCommentPattern = #"#[^\n\r]*"#
        case "sql":
            lineCommentPattern = #"--[^\n\r]*"#
        default:
            lineCommentPattern = ""
        }

        if !lineCommentPattern.isEmpty {
            stash(pattern: lineCommentPattern, tokenClass: "tok-comment")
        }

        stash(pattern: #"\"([^\"\\]|\\.)*\""#, tokenClass: "tok-string")
        stash(pattern: #"'([^'\\]|\\.)*'"#, tokenClass: "tok-string")
        stash(pattern: #"`([^`\\]|\\.)*`"#, tokenClass: "tok-string")

        let keywords = keywordsForLanguage(language)
        if !keywords.isEmpty {
            let keywordPattern = #"(?<![A-Za-z0-9_])("# + keywords.joined(separator: "|") + #")(?![A-Za-z0-9_])"#
            working = working.replacing(
                pattern: keywordPattern,
                with: #"<span class="tok-keyword">$1</span>"#,
                options: language == "sql" ? [.caseInsensitive] : []
            )
        }

        let literalPattern = #"(?<![A-Za-z0-9_])(true|false|null|nil|None|True|False)(?![A-Za-z0-9_])"#
        working = working.replacing(
            pattern: literalPattern,
            with: #"<span class="tok-literal">$1</span>"#
        )

        working = working.replacing(
            pattern: #"(?<![A-Za-z0-9_])([0-9]+(?:\.[0-9]+)?)(?![A-Za-z0-9_])"#,
            with: #"<span class="tok-number">$1</span>"#
        )

        for (placeholder, tokenHTML) in placeholders {
            working = working.replacingOccurrences(of: placeholder, with: tokenHTML)
        }

        return working
    }

    private func keywordsForLanguage(_ language: String) -> [String] {
        switch language {
        case "swift":
            return [
                "let", "var", "func", "if", "else", "guard", "return", "struct", "class", "enum", "protocol",
                "extension", "import", "for", "while", "switch", "case", "default", "break", "continue",
                "do", "try", "catch", "throw", "in", "public", "private", "fileprivate", "internal", "open",
                "static", "where", "defer", "async", "await"
            ]
        case "javascript", "js", "typescript", "ts":
            return [
                "const", "let", "var", "function", "if", "else", "return", "class", "new", "import", "export",
                "from", "async", "await", "try", "catch", "throw", "switch", "case", "default", "break",
                "continue", "for", "while"
            ]
        case "python", "py":
            return [
                "def", "class", "if", "elif", "else", "return", "import", "from", "as", "for", "while",
                "try", "except", "finally", "with", "lambda", "pass", "break", "continue"
            ]
        case "shell", "bash", "zsh", "sh":
            return ["if", "then", "else", "fi", "for", "do", "done", "case", "esac", "function", "in"]
        case "sql":
            return [
                "select", "from", "where", "join", "left", "right", "inner", "outer", "group", "by", "order",
                "having", "insert", "into", "update", "delete", "values", "limit", "offset", "and", "or", "as"
            ]
        case "json":
            return []
        default:
            return []
        }
    }

    private func buildMetadata(
        fromBodyHTML bodyHTML: String,
        fallbackTitle: String,
        frontMatter: [String: String]
    ) -> MarkdownRenderMetadata {
        let firstHeading = extractFirstMatch(
            pattern: #"<h1[^>]*>([\s\S]*?)</h1>"#,
            in: bodyHTML
        )?.strippingHTMLTags().decodeBasicHTMLEntities().trimmingCharacters(in: .whitespacesAndNewlines)

        let firstParagraph = extractFirstMatch(
            pattern: #"<p>([\s\S]*?)</p>"#,
            in: bodyHTML
        )?.strippingHTMLTags().decodeBasicHTMLEntities().collapsingWhitespace()

        let searchableText = bodyHTML
            .strippingHTMLTags()
            .decodeBasicHTMLEntities()
            .collapsingWhitespace()

        let frontMatterTitle = frontMatter["title"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let frontMatterDescription = frontMatter["description"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let frontMatterKeywords = frontMatter["tags"] ?? frontMatter["keywords"]

        let title = (frontMatterTitle?.isEmpty == false)
            ? frontMatterTitle!
            : (firstHeading?.isEmpty == false ? firstHeading! : fallbackTitle)

        let description = (frontMatterDescription?.isEmpty == false)
            ? frontMatterDescription!
            : (firstParagraph?.isEmpty == false ? firstParagraph! : searchableText.prefix(220).description)

        let keywords: [String]
        if let frontMatterKeywords, !frontMatterKeywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keywords = frontMatterKeywords
                .split(whereSeparator: { $0 == "," || $0 == ";" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else {
            keywords = extractKeywords(from: searchableText)
        }

        return MarkdownRenderMetadata(
            title: title,
            description: description,
            keywords: keywords,
            searchableText: String(searchableText.prefix(12_000))
        )
    }

    private func extractFirstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        return (text as NSString).substring(with: match.range(at: 1))
    }

    private func extractKeywords(from plainText: String) -> [String] {
        let words = plainText
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }

        var counts: [String: Int] = [:]
        for word in words {
            counts[word, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(12)
            .map(\.key)
    }

    private func slugifyHeading(_ heading: String) -> String {
        let normalized = heading
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()

        var slug = normalized.replacing(pattern: #"[^a-z0-9]+"#, with: "-")
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "section" : slug
    }

    private func wrapInDocument(bodyHTML: String, metadata: MarkdownRenderMetadata) -> String {
        let escapedTitle = escapeHTML(metadata.title)
        let escapedDescription = escapeHTML(metadata.description)
        let escapedKeywords = escapeHTML(metadata.keywords.joined(separator: ", "))

        return """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escapedTitle)</title>
            <meta name="description" content="\(escapedDescription)">
            <meta name="keywords" content="\(escapedKeywords)">
            <style>
                :root {
                    color-scheme: light dark;
                    --bg: #f8f8f8;
                    --text: #202124;
                    --muted: #5f6368;
                    --code-bg: #eceff1;
                    --border: #dadce0;
                    --link: #0b57d0;
                    --tok-comment: #6a737d;
                    --tok-string: #0b6e4f;
                    --tok-number: #8a3ffc;
                    --tok-keyword: #b42318;
                    --tok-literal: #9f1853;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #111315;
                        --text: #e8eaed;
                        --muted: #9aa0a6;
                        --code-bg: #1f2327;
                        --border: #303134;
                        --link: #8ab4f8;
                        --tok-comment: #8b949e;
                        --tok-string: #7ee787;
                        --tok-number: #d2a8ff;
                        --tok-keyword: #ff7b72;
                        --tok-literal: #f2cc60;
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
                    padding: 20px;
                    box-sizing: border-box;
                }
                h1, h2, h3, h4, h5, h6 {
                    line-height: 1.25;
                    margin-top: 1.2em;
                    margin-bottom: 0.45em;
                }
                h1:first-child, h2:first-child, h3:first-child, h4:first-child, h5:first-child, h6:first-child {
                    margin-top: 0;
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
                .tok-comment { color: var(--tok-comment); }
                .tok-string { color: var(--tok-string); }
                .tok-number { color: var(--tok-number); }
                .tok-keyword { color: var(--tok-keyword); font-weight: 600; }
                .tok-literal { color: var(--tok-literal); font-weight: 600; }
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
        <div style="position:absolute;left:-99999px;top:auto;width:1px;height:1px;overflow:hidden;" aria-hidden="true">\(escapeHTML(metadata.searchableText))</div>
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
    func firstMatch(pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let range = NSRange(location: 0, length: utf16.count)
        guard let match = regex.firstMatch(in: self, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let swiftRange = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[swiftRange])
    }

    func replacing(pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return self
        }
        let range = NSRange(location: 0, length: utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
    }

    func strippingHTMLTags() -> String {
        replacing(pattern: #"<[^>]+>"#, with: " ")
    }

    func decodeBasicHTMLEntities() -> String {
        self
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    func collapsingWhitespace() -> String {
        replacing(pattern: #"\s+"#, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
