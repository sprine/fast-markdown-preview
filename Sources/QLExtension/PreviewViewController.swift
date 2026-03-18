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

            // loadHTMLString silently fails in sandboxed extensions —
            // write to a temp file and load via file URL instead.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("html")
            try fullHTML.write(to: tempURL, atomically: true, encoding: .utf8)
            webView.loadFileURL(tempURL, allowingReadAccessTo: tempURL.deletingLastPathComponent())
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
