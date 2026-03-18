import AppKit
import WebKit

final class WebViewController: NSViewController {
    private var webView: WKWebView!
    private var currentURL: URL?
    private let renderer = MarkdownRenderer()

    var theme: CSSTheme = {
        let raw = UserDefaults.standard.string(forKey: "cssTheme") ?? CSSTheme.github.rawValue
        return CSSTheme(rawValue: raw) ?? .github
    }()

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        view = webView
    }

    func load(markdownAt url: URL) {
        currentURL = url
        render(url: url, scrollTo: 0)
    }

    func reload(markdownAt url: URL) {
        currentURL = url
        webView.evaluateJavaScript("window.scrollY") { [weak self] result, _ in
            let scrollY = (result as? Double) ?? 0
            self?.render(url: url, scrollTo: scrollY)
        }
    }

    private func render(url: URL, scrollTo: Double) {
        guard let markdown = try? String(contentsOf: url, encoding: .utf8) else { return }
        let htmlBody = renderer.renderHTML(from: markdown)
        let html = HTMLTemplate.wrap(htmlBody: htmlBody, theme: theme)
        let baseURL = url.deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: baseURL)
        pendingScrollY = scrollTo
    }

    private var pendingScrollY: Double = 0

    func showFileGoneBanner() {
        webView.evaluateJavaScript(
            "document.getElementById('file-gone-banner').style.display='block';",
            completionHandler: nil
        )
    }

    func applyTheme(_ theme: CSSTheme) {
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "cssTheme")
        if let url = currentURL {
            reload(markdownAt: url)
        }
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if pendingScrollY > 0 {
            webView.evaluateJavaScript("window.scrollTo(0, \(pendingScrollY));",
                                       completionHandler: nil)
            pendingScrollY = 0
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated,
           let url = action.request.url,
           url.scheme != "about" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
