import Foundation

enum CSSTheme: String, CaseIterable {
    case github = "github"
    case system = "system"

    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .system: return "System Native"
        }
    }
}

struct HTMLTemplate {
    static func wrap(htmlBody: String, theme: CSSTheme) -> String {
        let cssName = theme.rawValue
        guard let cssURL = Bundle.main.url(forResource: cssName, withExtension: "css"),
              let css = try? String(contentsOf: cssURL) else {
            return "<html><body>\(htmlBody)</body></html>"
        }
        guard let hlURL = Bundle.main.url(forResource: "highlight.min", withExtension: "js"),
              let hljs = try? String(contentsOf: hlURL) else {
            return wrapWithCSS(css, body: htmlBody)
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>\(css)</style>
        </head>
        <body>
          <div id="file-gone-banner">\u{26A0}\u{FE0F} File no longer available at this path.</div>
          \(htmlBody)
          <script>\(hljs)</script>
          <script>
            document.querySelectorAll('pre code[class*="language-"]').forEach(el => {
              hljs.highlightElement(el);
            });
          </script>
        </body>
        </html>
        """
    }

    private static func wrapWithCSS(_ css: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>\(css)</style></head>
        <body>
          <div id="file-gone-banner">\u{26A0}\u{FE0F} File no longer available at this path.</div>
          \(body)
        </body>
        </html>
        """
    }
}
