import XCTest
@testable import SimpleMarkdown

final class MarkdownRendererTests: XCTestCase {
    func testRendersCommonMarkdown() {
        let html = MarkdownRenderer.bodyHTML(from: """
        # Title

        This is **bold**, *italic*, and `code`.

        - One
        - Two

        [Example](https://example.com)
        """)

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>One</li>"))
        XCTAssertTrue(html.contains(#"<a href="https://example.com">Example</a>"#))
    }

    func testEscapesHTMLInParagraphsAndCodeBlocks() {
        let html = MarkdownRenderer.bodyHTML(from: """
        <script>alert("nope")</script>

        ```
        <h1>Not HTML</h1>
        ```
        """)

        XCTAssertTrue(html.contains("&lt;script&gt;alert(&quot;nope&quot;)&lt;/script&gt;"))
        XCTAssertTrue(html.contains("&lt;h1&gt;Not HTML&lt;/h1&gt;"))
        XCTAssertFalse(html.contains("<script>"))
    }

    func testFullHTMLDocumentIncludesVisiblePreviewStyles() {
        let html = MarkdownRenderer.htmlDocument(from: "# Visible\n\nPreview text")

        XCTAssertTrue(html.contains("<h1>Visible</h1>"))
        XCTAssertTrue(html.contains("background: var(--background);"))
        XCTAssertTrue(html.contains("color: var(--body);"))
        XCTAssertFalse(html.contains("light-dark("))
    }

    func testRendersMarkdownGuideBasicSyntaxCoverage() {
        let html = MarkdownRenderer.bodyHTML(from: """
        Heading level 1
        ===============

        Heading level 2
        ---------------

        First line with two spaces.  
        Second line.

        This is ***very*** important.

            let value = 42

        I use [Markdown Guide][guide].
        <fake@example.com>

        - 1968\\. A great year!

        [guide]: https://www.markdownguide.org "Markdown Guide"
        """)

        XCTAssertTrue(html.contains("<h1>Heading level 1</h1>"), "Missing setext h1 in:\n\(html)")
        XCTAssertTrue(html.contains("<h2>Heading level 2</h2>"), "Missing setext h2 in:\n\(html)")
        XCTAssertTrue(html.contains("First line with two spaces.<br>"), "Missing hard line break in:\n\(html)")
        XCTAssertTrue(html.contains("<strong><em>very</em></strong>"), "Missing bold italic in:\n\(html)")
        XCTAssertTrue(html.contains("<pre><code>let value = 42</code></pre>"), "Missing indented code block in:\n\(html)")
        XCTAssertTrue(html.contains(#"<a href="https://www.markdownguide.org" title="Markdown Guide">Markdown Guide</a>"#), "Missing reference link in:\n\(html)")
        XCTAssertTrue(html.contains(#"<a href="mailto:fake@example.com">fake@example.com</a>"#), "Missing email autolink in:\n\(html)")
        XCTAssertTrue(html.contains("<li>1968. A great year!</li>"), "Missing escaped list marker text in:\n\(html)")
    }
}
