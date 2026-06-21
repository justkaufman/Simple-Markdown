import Foundation

enum MarkdownAutoPairing {
    static func closingDelimiter(for typedText: String) -> String? {
        switch typedText {
        case "[":
            return "]"
        case "(":
            return ")"
        case "{":
            return "}"
        case "\"", "'", "`", "*", "_":
            return typedText
        default:
            return nil
        }
    }

    static func isClosingDelimiter(_ typedText: String) -> Bool {
        ["]", ")", "}", "\"", "'", "`", "*", "_"].contains(typedText)
    }

    static func isEmphasisDelimiter(_ typedText: String) -> Bool {
        typedText == "*" || typedText == "_"
    }

    static func matchingOpeningDelimiter(for closingText: String) -> String? {
        switch closingText {
        case "]":
            return "["
        case ")":
            return "("
        case "}":
            return "{"
        case "\"", "'", "`", "*", "_":
            return closingText
        default:
            return nil
        }
    }
}

