import XCTest
@testable import SimpleMarkdown

final class MarkdownPreviewAttributedRendererTests: XCTestCase {
    func testPreviewDoesNotDuplicateListMarkers() {
        let attributed = MarkdownPreviewAttributedRenderer.attributedString(from: """
        - One
        - Two

        1. First
        2. Second
        """)

        XCTAssertEqual(attributed.string.components(separatedBy: "•").count - 1, 2)
        XCTAssertEqual(attributed.string.components(separatedBy: "1.").count - 1, 1)
        XCTAssertEqual(attributed.string.components(separatedBy: "2.").count - 1, 1)
        XCTAssertFalse(attributed.string.contains("•\t•"))
        XCTAssertFalse(attributed.string.contains("1.\t1."))
        XCTAssertFalse(attributed.string.contains("2.\t2."))
    }

    func testPreviewRendersHighlightWithoutDelimiters() {
        let attributed = MarkdownPreviewAttributedRenderer.attributedString(from: """
        This is =highlighted= and ==also highlighted==.
        """)

        XCTAssertEqual(attributed.string, "This is highlighted and also highlighted.")

        let firstRange = (attributed.string as NSString).range(of: "highlighted")
        let secondRange = (attributed.string as NSString).range(of: "also highlighted")

        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: firstRange.location, effectiveRange: nil))
        XCTAssertNotNil(attributed.attribute(.backgroundColor, at: secondRange.location, effectiveRange: nil))
    }

    func testPreviewRendersMarkdownGuideBasicSyntaxText() {
        let attributed = MarkdownPreviewAttributedRenderer.attributedString(from: """
        Heading level 1
        ===============

        First line with two spaces.  
        Second line.

        This is ***very*** important.

            let value = 42

        I use [Markdown Guide][guide].
        <fake@example.com>

        [guide]: https://www.markdownguide.org "Markdown Guide"
        """)

        XCTAssertTrue(attributed.string.contains("Heading level 1"))
        XCTAssertTrue(attributed.string.contains("First line with two spaces.\nSecond line."))
        XCTAssertTrue(attributed.string.contains("This is very important."))
        XCTAssertTrue(attributed.string.contains("let value = 42"))
        XCTAssertTrue(attributed.string.contains("I use Markdown Guide."))
        XCTAssertTrue(attributed.string.contains("fake@example.com"))

        let linkRange = (attributed.string as NSString).range(of: "Markdown Guide")
        let emailRange = (attributed.string as NSString).range(of: "fake@example.com")
        XCTAssertNotNil(attributed.attribute(.link, at: linkRange.location, effectiveRange: nil))
        XCTAssertNotNil(attributed.attribute(.link, at: emailRange.location, effectiveRange: nil))
    }
}
