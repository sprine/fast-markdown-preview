import Cocoa
import Quartz
import WebKit

final class PreviewViewController: NSViewController, QLPreviewingController {

    private let webView = WKWebView()
    private let renderer = MarkdownRenderer()

    override func loadView() {
        view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            let htmlBody = renderer.renderHTML(from: markdown)
            let fullHTML = HTMLTemplate.wrap(htmlBody: htmlBody, theme: .github)
            webView.loadHTMLString(fullHTML, baseURL: nil)
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
