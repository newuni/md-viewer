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
    var onActiveHeadingChange: (String?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSearchResult: onSearchResult, onActiveHeadingChange: onActiveHeadingChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "activeHeading")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.onActiveHeadingChange = onActiveHeadingChange

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

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var lastHTML = ""
        var isPageLoaded = false
        var lastSearchRequestID: UUID?
        var lastScrollRequestID: UUID?
        var pendingSearchRequest: SearchRequest?
        var pendingScrollRequest: ScrollRequest?
        var onSearchResult: (Bool) -> Void
        var onActiveHeadingChange: (String?) -> Void

        init(onSearchResult: @escaping (Bool) -> Void, onActiveHeadingChange: @escaping (String?) -> Void) {
            self.onSearchResult = onSearchResult
            self.onActiveHeadingChange = onActiveHeadingChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            installScrollSync(on: webView)
            applyPendingCommands()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "activeHeading" else { return }
            if let anchor = message.body as? String, !anchor.isEmpty {
                onActiveHeadingChange(anchor)
            } else {
                onActiveHeadingChange(nil)
            }
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


        private func installScrollSync(on webView: WKWebView) {
            let script = """
            (() => {
                const headings = Array.from(document.querySelectorAll('h1[id],h2[id],h3[id],h4[id]'));
                const notify = () => {
                    if (!headings.length) {
                        window.webkit.messageHandlers.activeHeading.postMessage('');
                        return;
                    }
                    const threshold = 120;
                    let active = headings[0].id;
                    for (const h of headings) {
                        const top = h.getBoundingClientRect().top;
                        if (top <= threshold) active = h.id;
                        else break;
                    }
                    window.webkit.messageHandlers.activeHeading.postMessage(active || '');
                };
                window.__mdvNotifyActiveHeading = notify;
                window.removeEventListener('scroll', notify);
                window.addEventListener('scroll', notify, { passive: true });
                notify();
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
            webView.evaluateJavaScript("window.__mdvNotifyActiveHeading && window.__mdvNotifyActiveHeading();", completionHandler: nil)
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
            webView.evaluateJavaScript("window.__mdvNotifyActiveHeading && window.__mdvNotifyActiveHeading();", completionHandler: nil)
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
