import Foundation

enum MarkdownMode: String, CaseIterable, Identifiable {
    case edit = "Edit"
    case preview = "Preview"
    case split = "Split"

    var id: String { rawValue }
}

