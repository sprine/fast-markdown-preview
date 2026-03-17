import XCTest

final class MarkdownRendererTests: XCTestCase {
    let renderer = MarkdownRenderer()

    func testBasicParagraph() {
        let html = renderer.renderHTML(from: "Hello **world**")
        XCTAssertTrue(html.contains("<strong>world</strong>"), "Expected bold: \(html)")
        XCTAssertTrue(html.contains("<p>"), "Expected paragraph: \(html)")
    }

    func testGFMTable() {
        let md = """
        | Col A | Col B |
        |-------|-------|
        | 1     | 2     |
        """
        let html = renderer.renderHTML(from: md)
        XCTAssertTrue(html.contains("<table>"), "Expected table: \(html)")
        XCTAssertTrue(html.contains("<td>"), "Expected table cells: \(html)")
    }

    func testGFMStrikethrough() {
        let html = renderer.renderHTML(from: "~~deleted~~")
        XCTAssertTrue(html.contains("<del>"), "Expected strikethrough: \(html)")
    }

    func testGFMTaskList() {
        let md = """
        - [x] Done
        - [ ] Todo
        """
        let html = renderer.renderHTML(from: md)
        XCTAssertTrue(html.contains("checked"), "Expected checked checkbox: \(html)")
    }

    func testGFMAutolink() {
        let html = renderer.renderHTML(from: "Visit https://example.com")
        XCTAssertTrue(html.contains("<a href"), "Expected autolink: \(html)")
    }

    func testFencedCodeBlockWithLanguage() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        let html = renderer.renderHTML(from: md)
        XCTAssertTrue(html.contains("language-swift"), "Expected language class: \(html)")
    }

    func testEmptyInput() {
        let html = renderer.renderHTML(from: "")
        XCTAssertFalse(html.isEmpty)  // returns at least a minimal HTML document fragment
    }
}
