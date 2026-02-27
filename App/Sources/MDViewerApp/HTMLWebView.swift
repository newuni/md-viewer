import Foundation
import SwiftUI
import WebKit

struct HTMLWebView: NSViewRepresentable {
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

    let html: String
    var searchRequest: SearchRequest?
    var scrollRequest: ScrollRequest?
    var onSearchResult: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSearchResult: onSearchResult)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSearchResult = onSearchResult

        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            context.coordinator.isPageLoaded = false
            webView.loadHTMLString(html, baseURL: nil)
        }

        context.coordinator.handle(
            searchRequest: searchRequest,
            scrollRequest: scrollRequest
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var lastHTML = ""
        var isPageLoaded = false
        var lastSearchRequestID: UUID?
        var lastScrollRequestID: UUID?
        var pendingSearchRequest: SearchRequest?
        var pendingScrollRequest: ScrollRequest?
        var onSearchResult: (Bool) -> Void

        init(onSearchResult: @escaping (Bool) -> Void) {
            self.onSearchResult = onSearchResult
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            applyPendingCommands()
        }

        func handle(searchRequest: SearchRequest?, scrollRequest: ScrollRequest?) {
            if let searchRequest, searchRequest.id != lastSearchRequestID {
                lastSearchRequestID = searchRequest.id
                pendingSearchRequest = searchRequest
            }

            if let scrollRequest, scrollRequest.id != lastScrollRequestID {
                lastScrollRequestID = scrollRequest.id
                pendingScrollRequest = scrollRequest
            }

            applyPendingCommands()
        }

        private func applyPendingCommands() {
            guard isPageLoaded, let webView else {
                return
            }

            if let pendingSearchRequest {
                executeSearch(request: pendingSearchRequest, on: webView)
                self.pendingSearchRequest = nil
            }

            if let pendingScrollRequest {
                executeScroll(request: pendingScrollRequest, on: webView)
                self.pendingScrollRequest = nil
            }
        }

        private func executeSearch(request: SearchRequest, on webView: WKWebView) {
            let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
            let queryLiteral = javascriptQuotedString(query)
            let script = """
            (() => {
                const query = \(queryLiteral);
                if (!query) {
                    return false;
                }

                if (\(request.resetSelection ? "true" : "false")) {
                    const selection = window.getSelection();
                    if (selection) {
                        selection.removeAllRanges();
                    }
                    window.scrollTo(0, \(request.backwards ? "document.body.scrollHeight" : "0"));
                }

                return window.find(
                    query,
                    \(request.caseSensitive ? "true" : "false"),
                    \(request.backwards ? "true" : "false"),
                    true,
                    false,
                    false,
                    false
                );
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] result, _ in
                let found: Bool
                if let boolResult = result as? Bool {
                    found = boolResult
                } else if let numberResult = result as? NSNumber {
                    found = numberResult.boolValue
                } else {
                    found = false
                }
                self?.onSearchResult(found)
            }
        }

        private func executeScroll(request: ScrollRequest, on webView: WKWebView) {
            let anchorLiteral = javascriptQuotedString(request.anchor)
            let script = """
            (() => {
                const anchor = \(anchorLiteral);
                const element = document.getElementById(anchor);
                if (!element) {
                    return false;
                }
                element.scrollIntoView({ behavior: "auto", block: "start" });
                return true;
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func javascriptQuotedString(_ value: String) -> String {
            guard
                let data = try? JSONSerialization.data(withJSONObject: [value]),
                let encoded = String(data: data, encoding: .utf8)
            else {
                return "\"\""
            }
            return String(encoded.dropFirst().dropLast())
        }
    }
}
