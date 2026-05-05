import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import MarkdownRendererCore

private enum RenderTier: String {
    case small
    case medium
    case large
    case huge
}

private enum PaletteAction: String, CaseIterable, Identifiable {
    case toggleTOC
    case cycleTheme
    case toggleFastMode
    case openWithDefault
    case exportHTML
    case toggleReadingMode
    case pastePreview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleTOC: return "Toggle Outline"
        case .cycleTheme: return "Switch Theme"
        case .toggleFastMode: return "Toggle Fast Mode"
        case .openWithDefault: return "Open With…"
        case .exportHTML: return "Export HTML"
        case .toggleReadingMode: return "Reading Mode"
        case .pastePreview: return "Paste Preview"
        }
    }

    var symbol: String {
        switch self {
        case .toggleTOC: return "list.bullet.indent"
        case .cycleTheme: return "paintbrush"
        case .toggleFastMode: return "bolt"
        case .openWithDefault: return "square.and.arrow.up"
        case .exportHTML: return "doc.badge.arrow.up"
        case .toggleReadingMode: return "text.justify"
        case .pastePreview: return "doc.on.clipboard"
        }
    }
}

struct MarkdownDocumentView: View {
    private static let largeFileThresholdBytes: Int64 = 5 * 1024 * 1024

    let document: MarkdownDocument
    let fileURL: URL?

    @Environment(\.colorScheme) private var colorScheme

    @State private var renderedNativeDocument: NativeRenderedMarkdownDocument?
    @State private var renderedFallbackDocument: RenderedMarkdownDocument?
    @State private var renderedErrorMessage: String?
    @State private var liveText: String?
    @State private var watcher: MarkdownFileWatcher?

    @State private var isTOCVisible = false
    @State private var isSearchVisible = false
    @State private var isReadingMode = false
    @State private var searchQuery = ""
    @State private var isCaseSensitiveSearch = false
    @State private var searchStatusMessage: String?
    @State private var lastSearchSignature: String?
    @State private var activeHeadingAnchor: String?

    @State private var isCommandPaletteVisible = false
    @State private var commandPaletteQuery = ""
    @FocusState private var isCommandPaletteFocused: Bool

    @State private var clipboardPreviewText: String?

    @FocusState private var isSearchFieldFocused: Bool

    @State private var nativeSearchRequest: NativeMarkdownTextView.SearchRequest?
    @State private var nativeScrollRequest: NativeMarkdownTextView.ScrollRequest?
    @State private var fallbackSearchRequest: HTMLWebView.SearchRequest?
    @State private var fallbackScrollRequest: HTMLWebView.ScrollRequest?

    @State private var isLargeFile = false
    @State private var tier: RenderTier = .small
    @State private var fastModeOverride: Bool?

    @AppStorage("mdviewer.theme") private var selectedThemeRaw = MarkdownTheme.system.rawValue
    @AppStorage("mdviewer.appearance") private var selectedAppearanceRaw = MarkdownAppearance.system.rawValue
    @AppStorage("mdviewer.bodyFontSize") private var bodyFontSize = 16
    @AppStorage("mdviewer.codeFontSize") private var codeFontSize = 14

    private let renderer = MarkdownRenderer()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if isLargeFile, !isReadingMode {
                    largeFileBanner
                }

                if isSearchVisible, !isReadingMode {
                    searchBar
                }

                HStack(spacing: 0) {
                    if isTOCVisible, !isReadingMode {
                        tocSidebar
                        Divider()
                    }

                    previewContent
                }
            }

            if isCommandPaletteVisible {
                commandPalette
            }
        }
        .task(id: RenderTaskKey(
            text: effectiveMarkdownText,
            fastMode: isFastModeEnabled,
            theme: selectedThemeRaw,
            appearance: selectedAppearanceRaw,
            colorScheme: colorScheme == .dark ? "dark" : "light",
            bodyFontSize: bodyFontSize,
            codeFontSize: codeFontSize
        )) {
            renderCurrentDocument()
        }
        .toolbar {
            if !isReadingMode {
                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        Picker("Theme", selection: $selectedThemeRaw) {
                            Text("System").tag(MarkdownTheme.system.rawValue)
                            Text("GitHub").tag(MarkdownTheme.github.rawValue)
                            Text("Solarized").tag(MarkdownTheme.solarized.rawValue)
                            Text("Dracula").tag(MarkdownTheme.dracula.rawValue)
                        }

                        Picker("Appearance", selection: $selectedAppearanceRaw) {
                            Text("System").tag(MarkdownAppearance.system.rawValue)
                            Text("Light").tag(MarkdownAppearance.light.rawValue)
                            Text("Dark").tag(MarkdownAppearance.dark.rawValue)
                        }

                        Divider()

                        Stepper("Body size: \(bodyFontSize)", value: $bodyFontSize, in: 12...24)
                        Stepper("Code size: \(codeFontSize)", value: $codeFontSize, in: 11...22)
                    } label: {
                        Label("Style", systemImage: "paintbrush")
                    }
                    .help("Theme and typography")

                    Button {
                        isTOCVisible.toggle()
                    } label: {
                        Label("Toggle Outline", systemImage: "list.bullet.indent")
                    }
                    .help("Toggle table of contents")

                    Button {
                        toggleSearchVisibility()
                    } label: {
                        Label("Find", systemImage: "magnifyingglass")
                    }
                    .keyboardShortcut("f", modifiers: [.command])
                    .help("Find in document")

                    Button {
                        pastePreviewFromClipboard()
                    } label: {
                        Label("Paste Preview", systemImage: "doc.on.clipboard")
                    }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .help("Preview markdown directly from clipboard")

                    Menu {
                        ForEach(openWithApps, id: \.path) { app in
                            Button(app.deletingPathExtension().lastPathComponent) {
                                openCurrentFile(with: app)
                            }
                        }

                        if openWithApps.isEmpty {
                            Text("No applications available")
                        }
                    } label: {
                        Label("Open With", systemImage: "square.and.arrow.up")
                    }
                    .help("Open current file with another app")
                    .disabled(fileURL == nil)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            keyboardShortcutLayer
        }
        .onChange(of: searchQuery) { _, _ in
            searchStatusMessage = nil
        }
        .onChange(of: isCaseSensitiveSearch) { _, _ in
            lastSearchSignature = nil
        }
        .onAppear {
            startWatchingFileIfNeeded()
            refreshLargeFileState()
        }
        .onChange(of: fileURL) { _, _ in
            startWatchingFileIfNeeded()
            refreshLargeFileState()
        }
        .onDisappear {
            watcher?.stop()
            watcher = nil
        }
    }

    private var selectedTheme: MarkdownTheme {
        MarkdownTheme(rawValue: selectedThemeRaw) ?? .system
    }

    private var selectedAppearance: MarkdownAppearance {
        MarkdownAppearance(rawValue: selectedAppearanceRaw) ?? .system
    }

    private var resolvedNativeAppearance: MarkdownAppearance {
        guard selectedAppearance == .system else {
            return selectedAppearance
        }

        return colorScheme == .dark ? .dark : .light
    }

    private var isFastModeEnabled: Bool {
        fastModeOverride ?? (tier == .large || tier == .huge)
    }

    private var openWithApps: [URL] {
        guard let fileURL else { return [] }
        let ownBundleURL = Bundle.main.bundleURL.standardizedFileURL
        return NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
            .filter { $0.standardizedFileURL != ownBundleURL }
    }

    private var keyboardShortcutLayer: some View {
        Group {
            Button("Command Palette") {
                toggleCommandPalette()
            }
            .keyboardShortcut("k", modifiers: [.command])

            Button("Reading Mode") {
                isReadingMode.toggle()
            }
            .keyboardShortcut("r", modifiers: [.command, .control])

            Button("Zoom In") { adjustTypography(delta: 1) }
                .keyboardShortcut("=", modifiers: [.command])

            Button("Zoom Out") { adjustTypography(delta: -1) }
                .keyboardShortcut("-", modifiers: [.command])

            Button("Reset Zoom") { resetTypographyZoom() }
                .keyboardShortcut("0", modifiers: [.command])
        }
        .labelsHidden()
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .allowsHitTesting(false)
    }

    private var previewContent: some View {
        HStack {
            if isReadingMode { Spacer(minLength: 0) }
            Group {
                if renderedNativeDocument == nil, renderedFallbackDocument == nil, renderedErrorMessage == nil {
                    ContentUnavailableView(
                        "Rendering Markdown",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Loading preview...")
                    )
                } else if let renderedNativeDocument {
                    NativeMarkdownTextView(
                        attributedString: renderedNativeDocument.attributedString,
                        headingOffsets: headingOffsets,
                        backgroundColor: nativeBackgroundColor,
                        searchRequest: nativeSearchRequest,
                        scrollRequest: nativeScrollRequest
                    ) { found in
                        searchStatusMessage = found ? nil : "No matches"
                    } onActiveHeadingChange: { anchor in
                        activeHeadingAnchor = anchor
                    }
                } else if let renderedFallbackDocument {
                    HTMLWebView(
                        html: renderedFallbackDocument.html,
                        searchRequest: fallbackSearchRequest,
                        scrollRequest: fallbackScrollRequest
                    ) { found in
                        searchStatusMessage = found ? nil : "No matches"
                    } onActiveHeadingChange: { anchor in
                        activeHeadingAnchor = anchor
                    }
                } else {
                    ContentUnavailableView(
                        "Preview Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(renderedErrorMessage ?? "Rendering failed.")
                    )
                }
            }
            .frame(maxWidth: isReadingMode ? 860 : .infinity, maxHeight: .infinity)
            if isReadingMode { Spacer(minLength: 0) }
        }
        .padding(.vertical, isReadingMode ? 20 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var largeFileBanner: some View {
        HStack(spacing: 12) {
            Text("Large document detected (\(Self.largeFileThresholdBytes / (1024 * 1024))MB+).")
                .font(.callout)
            Text(isFastModeEnabled ? "Fast mode is enabled (\(tier.rawValue))." : "Fast mode is disabled.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button(isFastModeEnabled ? "Disable Fast Mode" : "Enable Fast Mode") {
                fastModeOverride = !isFastModeEnabled
            }
            .buttonStyle(.borderedProminent)

            if fastModeOverride != nil {
                Button("Auto") {
                    fastModeOverride = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.10))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Find in document", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    performSearch(backwards: false)
                }

            Button {
                performSearch(backwards: true)
            } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match")

            Button {
                performSearch(backwards: false)
            } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match")

            Button {
                isCaseSensitiveSearch.toggle()
            } label: {
                Text("Aa")
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 24)
            }
            .buttonStyle(.bordered)
            .tint(isCaseSensitiveSearch ? .accentColor : .secondary)
            .help("Case sensitive")

            if let searchStatusMessage {
                Text(searchStatusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                isSearchVisible = false
                searchStatusMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Close search")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
    }

    private var tocSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            if tocItems.isEmpty {
                Text(isFastModeEnabled ? "Outline is disabled in fast mode." : "No headings found.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(tocItems.enumerated()), id: \.offset) { _, heading in
                            Button {
                                scrollTo(anchor: heading.anchor)
                            } label: {
                                Text(heading.text)
                                    .font(.callout)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.leading, CGFloat(max(0, heading.level - 1) * 10))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            .background(activeHeadingAnchor == heading.anchor ? Color.accentColor.opacity(0.16) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contextMenu {
                                Button("Copy Link to Heading", systemImage: "link") {
                                    copyLinkToHeading(anchor: heading.anchor)
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 260)
        .background(Color.secondary.opacity(0.05))
    }

    private var commandPalette: some View {
        VStack(spacing: 10) {
            TextField("Type a command", text: $commandPaletteQuery)
                .textFieldStyle(.roundedBorder)
                .focused($isCommandPaletteFocused)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(filteredPaletteActions) { action in
                    Button {
                        runPaletteAction(action)
                    } label: {
                        HStack {
                            Image(systemName: action.symbol)
                                .foregroundStyle(.secondary)
                            Text(action.title)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: 420)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 24)
        .overlay(alignment: .topTrailing) {
            Button {
                isCommandPaletteVisible = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    private var filteredPaletteActions: [PaletteAction] {
        let query = commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return PaletteAction.allCases }
        return PaletteAction.allCases.filter { $0.title.lowercased().contains(query) }
    }

    private var effectiveMarkdownText: String {
        clipboardPreviewText ?? liveText ?? document.text
    }

    private var tocItems: [HeadingItem] {
        let source = renderedNativeDocument?.headings ?? renderedFallbackDocument?.headings ?? []
        return source.filter { (1...4).contains($0.level) }
    }

    private var headingOffsets: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: (renderedNativeDocument?.headings ?? [])
                .compactMap { heading in
                    guard let offset = heading.characterOffset else {
                        return nil
                    }
                    return (heading.anchor, offset)
                }
        )
    }

    private var renderOptions: MarkdownRenderOptions {
        MarkdownRenderOptions(
            syntaxHighlightingEnabled: !isFastModeEnabled,
            tocExtractionEnabled: !isFastModeEnabled,
            fastMode: isFastModeEnabled,
            theme: selectedTheme,
            appearance: selectedAppearance,
            bodyFontSize: bodyFontSize,
            codeFontSize: codeFontSize
        )
    }

    private var nativeRenderOptions: MarkdownRenderOptions {
        MarkdownRenderOptions(
            syntaxHighlightingEnabled: !isFastModeEnabled,
            tocExtractionEnabled: !isFastModeEnabled,
            fastMode: isFastModeEnabled,
            theme: selectedTheme,
            appearance: resolvedNativeAppearance,
            bodyFontSize: bodyFontSize,
            codeFontSize: codeFontSize
        )
    }

    private var nativeBackgroundColor: NSColor {
        switch (selectedTheme, resolvedNativeAppearance) {
        case (.system, .light):
            return NSColor(hex: 0xf8f8f8)
        case (.system, .dark):
            return NSColor(hex: 0x111315)
        case (.github, .light):
            return NSColor(hex: 0xffffff)
        case (.github, .dark):
            return NSColor(hex: 0x0d1117)
        case (.solarized, .light):
            return NSColor(hex: 0xfdf6e3)
        case (.solarized, .dark):
            return NSColor(hex: 0x002b36)
        case (.dracula, .light):
            return NSColor(hex: 0xf8f8f2)
        case (.dracula, .dark):
            return NSColor(hex: 0x282a36)
        case (_, .system):
            return colorScheme == .dark ? NSColor.windowBackgroundColor : NSColor.textBackgroundColor
        }
    }

    private var searchSignature: String {
        "\(isCaseSensitiveSearch)|\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func toggleSearchVisibility() {
        isSearchVisible.toggle()
        searchStatusMessage = nil
        if isSearchVisible {
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
    }

    private func performSearch(backwards: Bool) {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchStatusMessage = "Type text to search."
            return
        }

        let shouldResetSelection = lastSearchSignature != searchSignature
        lastSearchSignature = searchSignature
        nativeSearchRequest = NativeMarkdownTextView.SearchRequest(
            query: query,
            caseSensitive: isCaseSensitiveSearch,
            backwards: backwards,
            resetSelection: shouldResetSelection
        )
        fallbackSearchRequest = HTMLWebView.SearchRequest(
            query: query,
            caseSensitive: isCaseSensitiveSearch,
            backwards: backwards,
            resetSelection: shouldResetSelection
        )
    }

    private func renderCurrentDocument() {
        do {
            let rendered = try renderer.renderNativeDocument(
                markdown: effectiveMarkdownText,
                title: fileURL?.lastPathComponent ?? "Markdown Preview",
                options: nativeRenderOptions
            )
            renderedNativeDocument = rendered
            renderedFallbackDocument = nil
            renderedErrorMessage = nil
        } catch {
            do {
                let fallback = try renderer.renderDocument(
                    markdown: effectiveMarkdownText,
                    title: fileURL?.lastPathComponent ?? "Markdown Preview",
                    options: renderOptions
                )
                renderedNativeDocument = nil
                renderedFallbackDocument = fallback
                renderedErrorMessage = nil
            } catch {
                renderedNativeDocument = nil
                renderedFallbackDocument = nil
                renderedErrorMessage = error.localizedDescription
            }
        }
    }

    private func refreshLargeFileState() {
        guard let fileURL else {
            isLargeFile = false
            tier = .small
            fastModeOverride = nil
            return
        }

        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSizeBytes = Int64(values?.fileSize ?? 0)
        isLargeFile = fileSizeBytes >= Self.largeFileThresholdBytes

        switch fileSizeBytes {
        case ..<50_000:
            tier = .small
        case 50_000..<500_000:
            tier = .medium
        case 500_000..<5_000_000:
            tier = .large
        default:
            tier = .huge
        }
    }

    private func startWatchingFileIfNeeded() {
        watcher?.stop()
        watcher = nil

        guard let fileURL else {
            return
        }

        let watcher = MarkdownFileWatcher(fileURL: fileURL) {
            DispatchQueue.main.async {
                reloadFileFromDisk(fileURL)
            }
        }
        self.watcher = watcher
        watcher.start()
    }

    private func reloadFileFromDisk(_ fileURL: URL) {
        guard
            let data = try? Data(contentsOf: fileURL),
            let text = String(data: data, encoding: .utf8)
        else {
            return
        }

        if text != liveText {
            liveText = text
        }
        refreshLargeFileState()
    }

    private func openCurrentFile(with appURL: URL) {
        guard let fileURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: configuration)
    }

    private func toggleCommandPalette() {
        isCommandPaletteVisible.toggle()
        if isCommandPaletteVisible {
            commandPaletteQuery = ""
            DispatchQueue.main.async {
                isCommandPaletteFocused = true
            }
        }
    }

    private func runPaletteAction(_ action: PaletteAction) {
        switch action {
        case .toggleTOC:
            isTOCVisible.toggle()
        case .cycleTheme:
            cycleTheme()
        case .toggleFastMode:
            fastModeOverride = !isFastModeEnabled
        case .openWithDefault:
            if let fileURL { NSWorkspace.shared.open(fileURL) }
        case .exportHTML:
            exportCurrentHTML()
        case .toggleReadingMode:
            isReadingMode.toggle()
        case .pastePreview:
            pastePreviewFromClipboard()
        }
        isCommandPaletteVisible = false
    }

    private func cycleTheme() {
        let all = [MarkdownTheme.system, .github, .solarized, .dracula]
        let current = MarkdownTheme(rawValue: selectedThemeRaw) ?? .system
        let idx = all.firstIndex(of: current) ?? 0
        selectedThemeRaw = all[(idx + 1) % all.count].rawValue
    }

    private func exportCurrentHTML() {
        do {
            let rendered = try renderer.renderDocument(
                markdown: effectiveMarkdownText,
                title: fileURL?.lastPathComponent ?? "Markdown Preview",
                options: renderOptions
            )
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? "preview") + ".html"
            if panel.runModal() == .OK, let url = panel.url {
                try rendered.html.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            renderedErrorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func pastePreviewFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string), !content.isEmpty else {
            searchStatusMessage = "Clipboard does not contain text"
            return
        }
        clipboardPreviewText = content
        searchStatusMessage = "Previewing clipboard text"
    }

    private func scrollTo(anchor: String) {
        nativeScrollRequest = NativeMarkdownTextView.ScrollRequest(anchor: anchor)
        fallbackScrollRequest = HTMLWebView.ScrollRequest(anchor: anchor)
        activeHeadingAnchor = anchor
    }

    private func copyLinkToHeading(anchor: String) {
        let path = fileURL?.path(percentEncoded: false) ?? ""
        let output = "mdviewer://heading?file=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")#\(anchor)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }

    private func adjustTypography(delta: Int) {
        bodyFontSize = min(24, max(12, bodyFontSize + delta))
        codeFontSize = min(22, max(11, codeFontSize + delta))
    }

    private func resetTypographyZoom() {
        bodyFontSize = 16
        codeFontSize = 14
    }
}

private struct RenderTaskKey: Hashable {
    let text: String
    let fastMode: Bool
    let theme: String
    let appearance: String
    let colorScheme: String
    let bodyFontSize: Int
    let codeFontSize: Int
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255.0,
            green: CGFloat((hex >> 8) & 0xff) / 255.0,
            blue: CGFloat(hex & 0xff) / 255.0,
            alpha: 1
        )
    }
}
