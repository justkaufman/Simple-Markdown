import XCTest
@testable import SimpleMarkdown

final class MarkdownAutoPairingTests: XCTestCase {
    func testProvidesClosingDelimitersForMarkdownPairs() {
        XCTAssertEqual(MarkdownAutoPairing.closingDelimiter(for: "["), "]")
        XCTAssertEqual(MarkdownAutoPairing.closingDelimiter(for: "("), ")")
        XCTAssertEqual(MarkdownAutoPairing.closingDelimiter(for: "{"), "}")
        XCTAssertEqual(MarkdownAutoPairing.closingDelimiter(for: "`"), "`")
        XCTAssertEqual(MarkdownAutoPairing.closingDelimiter(for: "*"), "*")
        XCTAssertEqual(MarkdownAutoPairing.closingDelimiter(for: "_"), "_")
    }

    func testRecognizesClosingDelimiters() {
        XCTAssertTrue(MarkdownAutoPairing.isClosingDelimiter("]"))
        XCTAssertTrue(MarkdownAutoPairing.isClosingDelimiter(")"))
        XCTAssertTrue(MarkdownAutoPairing.isClosingDelimiter("*"))
        XCTAssertFalse(MarkdownAutoPairing.isClosingDelimiter("a"))
    }

    func testRecognizesEmphasisDelimiters() {
        XCTAssertTrue(MarkdownAutoPairing.isEmphasisDelimiter("*"))
        XCTAssertTrue(MarkdownAutoPairing.isEmphasisDelimiter("_"))
        XCTAssertFalse(MarkdownAutoPairing.isEmphasisDelimiter("`"))
    }
}

