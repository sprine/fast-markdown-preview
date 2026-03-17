import Foundation

final class MarkdownRenderer {

    // GFM extension names recognized by cmark-gfm
    private static let extensions = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]

    init() {
        // Register all built-in GFM extensions once
        cmark_gfm_core_extensions_ensure_registered()
    }

    /// Converts GitHub-Flavored Markdown text to an HTML fragment string.
    func renderHTML(from markdown: String) -> String {
        let options = Int32(CMARK_OPT_UNSAFE | CMARK_OPT_SMART)

        // Build parser
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        // Attach GFM extensions
        for name in Self.extensions {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        // Feed and finish
        cmark_parser_feed(parser, markdown, markdown.utf8.count)
        guard let doc = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(doc) }

        // Render
        guard let rawPtr = cmark_render_html(doc, options, nil) else { return "\n" }
        defer { free(rawPtr) }

        let result = String(cString: rawPtr)
        return result.isEmpty ? "\n" : result
    }
}
