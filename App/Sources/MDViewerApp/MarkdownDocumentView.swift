import AppKit
import Foundation
import SwiftUI
import MarkdownRendererCore

private enum RenderTier: String {
    case small
    case medium
    case large
    case huge
}

struct MarkdownDocumentView: View {
    private static let largeFileThresholdBytes: Int64 = 5 * 1024 * 1024

    let document: MarkdownDocument
    let fileURL: URL?

    @State private var renderedDocument: RenderedMarkdownDocument?
    @State private var renderedErrorHTML = ""
    @State private var liveText: String?
    @State private var watcher: MarkdownFileWatcher?

    @State private var isTOCVisible = false
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var isCaseSensitiveSearch = false
    @State private var searchStatusMessage: String?
    @State private var lastSearchSignature: String?
    @FocusState private var isSearchFieldFocused: Bool

    @State private var searchRequest: HTMLWebView.SearchRequest?
    @State private var scrollRequest: HTMLWebView.ScrollRequest?

    @State private var isLargeFile = false
    @State private var tier: RenderTier = .small
    @State private var fastModeOverride: Bool?

    @AppStorage("mdviewer.theme") private var selectedThemeRaw = MarkdownTheme.system.rawValue
    @AppStorage("mdviewer.appearance") private var selectedAppearanceRaw = MarkdownAppearance.system.rawValue
    @AppStorage("mdviewer.bodyFontSize") private var bodyFontSize = 16
    @AppStorage("mdviewer.codeFontSize") private var codeFontSize = 14

    private let renderer = MarkdownRenderer()

    var body: some View {
        VStack(spacing: 0) {
            if isLargeFile {
                largeFileBanner
            }

            if isSearchVisible {
                searchBar
            }

            HStack(spacing: 0) {
                if isTOCVisible {
                    tocSidebar
                    Divider()
                }

                previewContent
            }
        }
        .task(id: RenderTaskKey(text: effectiveMarkdownText, fastMode: isFastModeEnabled, theme: selectedThemeRaw, appearance: selectedAppearanceRaw, bodyFontSize: bodyFontSize, codeFontSize: codeFontSize)) {
            renderCurrentDocument()
        }
        .toolbar {
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

    private var isFastModeEnabled: Bool {
        fastModeOverride ?? tier == .large || tier == .huge
    }

    private var openWithApps: [URL] {
        guard let fileURL else { return [] }
        let ownBundleURL = Bundle.main.bundleURL.standardizedFileURL
        return NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
            .filter { $0.standardizedFileURL != ownBundleURL }
    }

    private var previewContent: some View {
        Group {
            if renderedDocument == nil, renderedErrorHTML.isEmpty {
                ContentUnavailableView(
                    "Rendering Markdown",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Loading preview...")
                )
            } else {
                HTMLWebView(
                    html: renderedDocument?.html ?? renderedErrorHTML,
                    searchRequest: searchRequest,
                    scrollRequest: scrollRequest
                ) { found in
                    searchStatusMessage = found ? nil : "No matches"
                }
            }
        }
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
                                scrollRequest = HTMLWebView.ScrollRequest(anchor: heading.anchor)
                            } label: {
                                Text(heading.text)
                                    .font(.callout)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .padding(.leading, CGFloat(max(0, heading.level - 1) * 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 260)
        .background(Color.secondary.opacity(0.05))
    }

    private var effectiveMarkdownText: String {
        liveText ?? document.text
    }

    private var tocItems: [HeadingItem] {
        (renderedDocument?.headings ?? []).filter { (1...4).contains($0.level) }
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
        searchRequest = HTMLWebView.SearchRequest(
            query: query,
            caseSensitive: isCaseSensitiveSearch,
            backwards: backwards,
            resetSelection: shouldResetSelection
        )
    }

    private func renderCurrentDocument() {
        do {
            let rendered = try renderer.renderDocument(
                markdown: effectiveMarkdownText,
                title: fileURL?.lastPathComponent ?? "Markdown Preview",
                options: renderOptions
            )
            renderedDocument = rendered
            renderedErrorHTML = ""
        } catch {
            renderedDocument = nil
            renderedErrorHTML = """
            <!doctype html>
            <html><body><h2>Preview error</h2><p>\(error.localizedDescription)</p></body></html>
            """
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
}

private struct RenderTaskKey: Hashable {
    let text: String
    let fastMode: Bool
    let theme: String
    let appearance: String
    let bodyFontSize: Int
    let codeFontSize: Int
}
