import XCTest
@testable import SimpleMarkdown

final class MarkdownSyntaxReferenceTests: XCTestCase {
    func testRendersReferenceMarkdownFeaturesLocally() {
        let html = MarkdownRenderer.bodyHTML(from: """
        # Title

        | Name | Value |
        | --- | --- |
        | One | **Two** |

        - [x] Done
        - [ ] Todo

        ~~deleted~~
        =highlight=
        ==also highlighted==
        ![Alt text](image.png "Title")
        <https://example.com>
        """)

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>Name</th>"))
        XCTAssertTrue(html.contains("<td><strong>Two</strong></td>"))
        XCTAssertTrue(html.contains(#"<input type="checkbox" disabled checked> Done"#))
        XCTAssertTrue(html.contains(#"<input type="checkbox" disabled> Todo"#))
        XCTAssertTrue(html.contains("<s>deleted</s>"))
        XCTAssertTrue(html.contains("<mark>highlight</mark>"))
        XCTAssertTrue(html.contains("<mark>also highlighted</mark>"))
        XCTAssertTrue(html.contains(#"<img src="image.png" alt="Alt text" title="Title">"#))
        XCTAssertTrue(html.contains(#"<a href="https://example.com">https://example.com</a>"#))
    }
}
