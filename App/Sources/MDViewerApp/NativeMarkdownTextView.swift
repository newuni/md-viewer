import AppKit
import SwiftUI

@MainActor
struct NativeMarkdownTextView: NSViewRepresentable {
    struct SearchRequest: Equatable {
        let id: UUID
        let query: String
        let caseSensitive: Bool
        let backwards: Bool
        let resetSelection: Bool

        init(
            query: String,
            caseSensitive: Bool,
            backwards: Bool,
            resetSelection: Bool
        ) {
            self.id = UUID()
            self.query = query
            self.caseSensitive = caseSensitive
            self.backwards = backwards
            self.resetSelection = resetSelection
        }
    }

    struct ScrollRequest: Equatable {
        let id: UUID
        let anchor: String

        init(anchor: String) {
            self.id = UUID()
            self.anchor = anchor
        }
    }

    let attributedString: NSAttributedString
    let headingOffsets: [String: Int]
    var searchRequest: SearchRequest?
    var scrollRequest: ScrollRequest?
    var onSearchResult: (Bool) -> Void = { _ in }
    var onActiveHeadingChange: (String?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSearchResult: onSearchResult, onActiveHeadingChange: onActiveHeadingChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.importsGraphics = false
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.didScroll), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        scrollView.contentView.postsBoundsChangedNotifications = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.onActiveHeadingChange = onActiveHeadingChange
        context.coordinator.headingOffsets = headingOffsets
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.textView = textView
        let contentSignature = attributedString.string.hashValue ^ attributedString.length
        if context.coordinator.lastContentSignature != contentSignature {
            context.coordinator.lastContentSignature = contentSignature
            textView.textStorage?.setAttributedString(attributedString)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }

        context.coordinator.handle(
            searchRequest: searchRequest,
            scrollRequest: scrollRequest
        )
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var onSearchResult: (Bool) -> Void
        var onActiveHeadingChange: (String?) -> Void
        var headingOffsets: [String: Int] = [:]
        var lastContentSignature = 0
        var lastSearchRequestID: UUID?
        var lastScrollRequestID: UUID?
        var pendingSearchRequest: SearchRequest?
        var pendingScrollRequest: ScrollRequest?
        var sortedHeadingOffsets: [(String, Int)] = []

        init(onSearchResult: @escaping (Bool) -> Void, onActiveHeadingChange: @escaping (String?) -> Void) {
            self.onSearchResult = onSearchResult
            self.onActiveHeadingChange = onActiveHeadingChange
        }

        func handle(searchRequest: SearchRequest?, scrollRequest: ScrollRequest?) {
            sortedHeadingOffsets = headingOffsets.sorted { $0.value < $1.value }
            if let searchRequest, searchRequest.id != lastSearchRequestID {
                lastSearchRequestID = searchRequest.id
                pendingSearchRequest = searchRequest
            }

            if let scrollRequest, scrollRequest.id != lastScrollRequestID {
                lastScrollRequestID = scrollRequest.id
                pendingScrollRequest = scrollRequest
            }

            if let request = pendingSearchRequest {
                pendingSearchRequest = nil
                executeSearch(request: request)
            }

            if let request = pendingScrollRequest {
                pendingScrollRequest = nil
                executeScroll(request: request)
            }
        }

        private func executeSearch(request: SearchRequest) {
            guard let textView else {
                onSearchResult(false)
                return
            }

            let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                onSearchResult(false)
                return
            }

            let nsText = textView.string as NSString
            let fullLength = nsText.length
            guard fullLength > 0 else {
                onSearchResult(false)
                return
            }

            var options: NSString.CompareOptions = []
            if !request.caseSensitive {
                options.insert(.caseInsensitive)
            }
            if request.backwards {
                options.insert(.backwards)
            }

            if request.resetSelection {
                let resetLocation = request.backwards ? fullLength : 0
                textView.setSelectedRange(NSRange(location: resetLocation, length: 0))
            }

            let selectedRange = textView.selectedRange()
            let lowerBound = min(max(0, selectedRange.location), fullLength)
            let upperBound = min(fullLength, selectedRange.location + selectedRange.length)

            let primaryRange: NSRange
            let fallbackRange: NSRange
            if request.backwards {
                primaryRange = NSRange(location: 0, length: lowerBound)
                fallbackRange = NSRange(location: upperBound, length: max(0, fullLength - upperBound))
            } else {
                primaryRange = NSRange(location: upperBound, length: max(0, fullLength - upperBound))
                fallbackRange = NSRange(location: 0, length: lowerBound)
            }

            var found = nsText.range(of: query, options: options, range: primaryRange)
            if found.location == NSNotFound {
                found = nsText.range(of: query, options: options, range: fallbackRange)
            }

            guard found.location != NSNotFound else {
                onSearchResult(false)
                return
            }

            textView.setSelectedRange(found)
            textView.scrollRangeToVisible(found)
            onSearchResult(true)
        }


        @objc func didScroll(_ notification: Notification) {
            updateActiveHeadingFromVisibleRange()
        }

        private func updateActiveHeadingFromVisibleRange() {
            guard let textView else { return }
            if sortedHeadingOffsets.isEmpty {
                sortedHeadingOffsets = headingOffsets.sorted { $0.value < $1.value }
            }
            guard !sortedHeadingOffsets.isEmpty else {
                onActiveHeadingChange(nil)
                return
            }

            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let visiblePoint = NSPoint(x: textView.visibleRect.minX + 8, y: textView.visibleRect.minY + textView.textContainerInset.height + 8)
            let glyphIndex = layoutManager.glyphIndex(for: visiblePoint, in: textContainer)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            var active: String?
            for (anchor, offset) in sortedHeadingOffsets {
                if offset <= characterIndex {
                    active = anchor
                } else {
                    break
                }
            }
            onActiveHeadingChange(active ?? sortedHeadingOffsets.first?.0)
        }

        private func executeScroll(request: ScrollRequest) {
            guard let textView else {
                return
            }

            guard
                let location = headingOffsets[request.anchor],
                location >= 0,
                location <= (textView.string as NSString).length
            else {
                return
            }

            let target = NSRange(location: location, length: 0)
            textView.setSelectedRange(target)
            textView.scrollRangeToVisible(target)
            updateActiveHeadingFromVisibleRange()
        }
    }
}
