import AppKit
import SwiftUI

struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 28, height: 28)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.lastMarkdown != markdown else { return }

        context.coordinator.lastMarkdown = markdown
        guard let textView = context.coordinator.textView else { return }

        textView.textStorage?.setAttributedString(
            MarkdownPreviewAttributedRenderer.attributedString(from: markdown)
        )
        textView.backgroundColor = .textBackgroundColor
    }

    final class Coordinator {
        weak var textView: NSTextView?
        var lastMarkdown = ""
    }
}

enum MarkdownPreviewAttributedRenderer {
    static func attributedString(from markdown: String) -> NSAttributedString {
        let renderer = Renderer()
        return renderer.render(markdown)
    }

    private final class Renderer {
        private let result = NSMutableAttributedString()
        private let baseFont = NSFont.systemFont(ofSize: 15)
        private let bodyColor = NSColor.labelColor
        private let mutedColor = NSColor.secondaryLabelColor
        private let linkColor = NSColor.linkColor
        private let codeBackgroundColor = NSColor.controlBackgroundColor
        private let highlightBackgroundColor = NSColor(
            calibratedRed: 1.0,
            green: 0.91,
            blue: 0.35,
            alpha: 0.75
        )

        func render(_ markdown: String) -> NSAttributedString {
            let document = MarkdownPreviewDocumentParts(markdown: markdown)
            let lines = document.contentLines
            var index = 0
            var isInCodeBlock = false
            var codeLines: [String] = []

            while index < lines.count {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                index += 1

                if trimmed.hasPrefix("```") {
                    if isInCodeBlock {
                        appendCodeBlock(codeLines.joined(separator: "\n"))
                        codeLines = []
                        isInCodeBlock = false
                    } else {
                        isInCodeBlock = true
                    }
                    continue
                }

                if isInCodeBlock {
                    codeLines.append(line)
                    continue
                }

                guard !trimmed.isEmpty else {
                    appendBlankLine()
                    continue
                }

                if isIndentedCode(line) {
                    var codeBlockLines = [dropCodeIndent(from: line)]
                    while index < lines.count, lines[index].isEmpty || isIndentedCode(lines[index]) {
                        let codeLine = lines[index]
                        codeBlockLines.append(codeLine.isEmpty ? "" : dropCodeIndent(from: codeLine))
                        index += 1
                    }
                    trimTrailingBlankLines(from: &codeBlockLines)
                    appendCodeBlock(codeBlockLines.joined(separator: "\n"))
                } else if let table = tableRows(startingAt: index - 1, lines: lines) {
                    appendTable(headers: table.headers, rows: table.rows)
                    index = table.nextIndex
                } else if let setext = setextHeading(startingAt: index - 1, lines: lines) {
                    appendBlock(
                        setext.text,
                        style: headingStyle(level: setext.level),
                        baseAttributes: [.font: headingFont(level: setext.level)],
                        references: document.references
                    )
                    index = setext.nextIndex
                } else if let heading = heading(from: trimmed) {
                    appendBlock(
                        heading.text,
                        style: headingStyle(level: heading.level),
                        baseAttributes: [.font: headingFont(level: heading.level)],
                        references: document.references
                    )
                } else if isHorizontalRule(trimmed) {
                    appendBlock(String(repeating: "─", count: 32), style: mutedParagraphStyle())
                } else if let quote = blockquote(from: trimmed) {
                    appendBlock(
                        quote,
                        style: quoteStyle(),
                        baseAttributes: [.foregroundColor: mutedColor],
                        references: document.references
                    )
                } else if let item = unorderedListItem(from: trimmed) {
                    appendListItem(marker: "•", text: item, references: document.references)
                } else if let item = orderedListItem(from: trimmed) {
                    appendListItem(marker: "\(item.number).", text: item.text, references: document.references)
                } else {
                    var paragraphLines = [line]
                    while index < lines.count, shouldContinueParagraph(with: lines[index]) {
                        paragraphLines.append(lines[index])
                        index += 1
                    }
                    appendParagraph(paragraphLines, references: document.references)
                }
            }

            if isInCodeBlock {
                appendCodeBlock(codeLines.joined(separator: "\n"))
            }

            trimTrailingNewlines()
            return result.copy() as? NSAttributedString ?? result
        }

        private func appendBlock(
            _ text: String,
            style: NSParagraphStyle,
            baseAttributes: [NSAttributedString.Key: Any] = [:],
            references: [String: MarkdownPreviewLinkReference] = [:]
        ) {
            let attributes = mergedAttributes(
                [
                    .font: baseFont,
                    .foregroundColor: bodyColor,
                    .paragraphStyle: style
                ],
                baseAttributes
            )
            result.append(inlineAttributedString(from: text, baseAttributes: attributes, references: references))
            result.append(NSAttributedString(string: "\n"))
        }

        private func appendParagraph(_ lines: [String], references: [String: MarkdownPreviewLinkReference]) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: bodyColor,
                .paragraphStyle: paragraphStyle()
            ]

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let hasBreak = line.hasSuffix("  ") || trimmed.hasSuffix("<br>")
                let text = trimmed.hasSuffix("<br>") ? String(trimmed.dropLast(4)) : trimmed
                result.append(inlineAttributedString(from: text, baseAttributes: attributes, references: references))
                if index < lines.count - 1 {
                    result.append(NSAttributedString(string: hasBreak ? "\n" : " ", attributes: attributes))
                }
            }
            result.append(NSAttributedString(string: "\n"))
        }

        private func appendBlankLine() {
            if result.length > 0, !result.string.hasSuffix("\n\n") {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        private func appendListItem(
            marker: String,
            text: String,
            references: [String: MarkdownPreviewLinkReference]
        ) {
            if let task = taskListItem(from: text) {
                appendBlock(
                    "\(task.isChecked ? "☑" : "☐")\t\(task.text)",
                    style: listParagraphStyle(),
                    references: references
                )
                return
            }

            appendBlock("\(marker)\t\(text)", style: listParagraphStyle(), references: references)
        }

        private func appendCodeBlock(_ text: String) {
            let style = paragraphStyle()
            style.paragraphSpacingBefore = 6
            style.paragraphSpacing = 10

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: bodyColor,
                .backgroundColor: codeBackgroundColor,
                .paragraphStyle: style
            ]
            result.append(NSAttributedString(string: text, attributes: attributes))
            result.append(NSAttributedString(string: "\n"))
        }

        private func appendTable(headers: [String], rows: [[String]]) {
            let allRows = [headers] + rows
            let widths = columnWidths(for: allRows)

            appendTableRow(headers, widths: widths, isHeader: true)
            appendTableRow(widths.map { String(repeating: "─", count: max($0, 3)) }, widths: widths, isHeader: false)
            for row in rows {
                appendTableRow(normalizedTableCells(row, count: headers.count), widths: widths, isHeader: false)
            }
            appendBlankLine()
        }

        private func appendTableRow(_ row: [String], widths: [Int], isHeader: Bool) {
            let padded = zip(normalizedTableCells(row, count: widths.count), widths)
                .map { cell, width in cell.padding(toLength: width, withPad: " ", startingAt: 0) }
                .joined(separator: "  ")
            let font = isHeader
                ? NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
                : NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let style = paragraphStyle()
            style.paragraphSpacing = 2
            result.append(
                NSAttributedString(
                    string: padded + "\n",
                    attributes: [
                        .font: font,
                        .foregroundColor: bodyColor,
                        .paragraphStyle: style
                    ]
                )
            )
        }

        private func inlineAttributedString(
            from text: String,
            baseAttributes: [NSAttributedString.Key: Any],
            references: [String: MarkdownPreviewLinkReference]
        ) -> NSAttributedString {
            let attributed = NSMutableAttributedString(
                string: unescapeMarkdownEscapes(in: text),
                attributes: baseAttributes
            )

            replaceInline(pattern: #"\!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]+)")?\)"#, in: attributed) { match in
                let label = match[1].isEmpty ? match[2] : match[1]
                return (label, [.foregroundColor: mutedColor, .font: baseFont])
            }

            replaceInline(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, in: attributed) { match in
                let parts = parseInlineLinkDestination(match[2])
                return (match[1], [.link: parts.url, .foregroundColor: linkColor])
            }

            replaceInline(pattern: #"\[([^\]]+)\]\s?\[([^\]]+)\]"#, in: attributed) { match in
                guard let reference = references[MarkdownPreviewAttributedRenderer.normalizeReferenceLabel(match[2])] else {
                    return (match[0], [:])
                }
                return (match[1], [.link: reference.url, .foregroundColor: linkColor])
            }

            replaceInline(pattern: #"<(https?://[^>\s]+)>"#, in: attributed) { match in
                (match[1], [.link: match[1], .foregroundColor: linkColor])
            }

            replaceInline(pattern: #"<([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})>"#, options: [.caseInsensitive], in: attributed) { match in
                (match[1], [.link: "mailto:\(match[1])", .foregroundColor: linkColor])
            }

            replaceInline(pattern: #"`([^`]+)`"#, in: attributed) { match in
                (
                    match[1],
                    [
                        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                        .backgroundColor: codeBackgroundColor
                    ]
                )
            }

            replaceInline(pattern: #"~~([^~]+)~~"#, in: attributed) { match in
                (match[1], [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
            }

            replaceInline(pattern: #"\*\*\*([^*]+)\*\*\*"#, in: attributed) { match in
                (
                    match[1],
                    [
                        .font: italicFont(from: [.font: boldFont(from: baseAttributes)])
                    ]
                )
            }

            replaceInline(pattern: #"___([^_]+)___"#, in: attributed) { match in
                (
                    match[1],
                    [
                        .font: italicFont(from: [.font: boldFont(from: baseAttributes)])
                    ]
                )
            }

            replaceInline(pattern: #"==([^=]+)=="#, in: attributed) { match in
                (match[1], [.backgroundColor: highlightBackgroundColor])
            }

            replaceInline(pattern: #"(?<![=\w])=([^=\n]+)=(?![=\w])"#, in: attributed) { match in
                (match[1], [.backgroundColor: highlightBackgroundColor])
            }

            replaceInline(pattern: #"\*\*([^*]+)\*\*"#, in: attributed) { match in
                (match[1], [.font: boldFont(from: baseAttributes)])
            }

            replaceInline(pattern: #"__([^_]+)__"#, in: attributed) { match in
                (match[1], [.font: boldFont(from: baseAttributes)])
            }

            replaceInline(pattern: #"\*([^*]+)\*"#, in: attributed) { match in
                (match[1], [.font: italicFont(from: baseAttributes)])
            }

            replaceInline(pattern: #"_([^_]+)_"#, in: attributed) { match in
                (match[1], [.font: italicFont(from: baseAttributes)])
            }

            return attributed
        }

        private func replaceInline(
            pattern: String,
            options: NSRegularExpression.Options = [],
            in attributed: NSMutableAttributedString,
            replacement: ([String]) -> (text: String, attributes: [NSAttributedString.Key: Any])
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            let source = attributed.string as NSString
            let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: source.length))

            for match in matches.reversed() {
                let groups = (0..<match.numberOfRanges).map { index in
                    let range = match.range(at: index)
                    guard range.location != NSNotFound else { return "" }
                    return source.substring(with: range)
                }
                let replacement = replacement(groups)
                attributed.replaceCharacters(in: match.range, with: replacement.text)
                attributed.addAttributes(
                    replacement.attributes,
                    range: NSRange(location: match.range.location, length: (replacement.text as NSString).length)
                )
            }
        }

        private func headingStyle(level: Int) -> NSParagraphStyle {
            let style = paragraphStyle()
            style.paragraphSpacingBefore = level == 1 ? 0 : 12
            style.paragraphSpacing = 8
            return style
        }

        private func headingFont(level: Int) -> NSFont {
            let size: CGFloat
            switch level {
            case 1:
                size = 30
            case 2:
                size = 24
            case 3:
                size = 20
            case 4:
                size = 17
            default:
                size = 15
            }
            return NSFont.systemFont(ofSize: size, weight: .bold)
        }

        private func paragraphStyle() -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 2
            style.paragraphSpacing = 8
            return style
        }

        private func mutedParagraphStyle() -> NSMutableParagraphStyle {
            let style = paragraphStyle()
            style.paragraphSpacing = 10
            return style
        }

        private func quoteStyle() -> NSMutableParagraphStyle {
            let style = paragraphStyle()
            style.headIndent = 18
            style.firstLineHeadIndent = 18
            return style
        }

        private func listParagraphStyle() -> NSMutableParagraphStyle {
            let style = paragraphStyle()
            let markerColumn: CGFloat = 34
            style.tabStops = [NSTextTab(textAlignment: .left, location: markerColumn)]
            style.defaultTabInterval = markerColumn
            style.firstLineHeadIndent = 0
            style.headIndent = markerColumn
            style.paragraphSpacing = 5
            return style
        }

        private func heading(from line: String) -> (level: Int, text: String)? {
            let hashes = line.prefix(while: { $0 == "#" }).count
            guard (1...6).contains(hashes),
                  line.dropFirst(hashes).first == " " else {
                return nil
            }
            return (hashes, String(line.dropFirst(hashes + 1)))
        }

        private func setextHeading(startingAt startIndex: Int, lines: [String]) -> (level: Int, text: String, nextIndex: Int)? {
            guard startIndex + 1 < lines.count else { return nil }
            let text = lines[startIndex].trimmingCharacters(in: .whitespaces)
            let marker = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            if marker.allSatisfy({ $0 == "=" }), marker.count >= 2 {
                return (1, text, startIndex + 2)
            }
            if marker.allSatisfy({ $0 == "-" }), marker.count >= 2 {
                return (2, text, startIndex + 2)
            }
            return nil
        }

        private func blockquote(from line: String) -> String? {
            guard line.hasPrefix(">") else { return nil }
            return line.dropFirst().trimmingCharacters(in: .whitespaces)
        }

        private func unorderedListItem(from line: String) -> String? {
            guard line.count > 2 else { return nil }
            let marker = line.prefix(2)
            guard marker == "- " || marker == "* " || marker == "+ " else { return nil }
            return String(line.dropFirst(2))
        }

        private func orderedListItem(from line: String) -> (number: String, text: String)? {
            guard let dot = line.firstIndex(of: ".") else { return nil }
            let prefix = line[..<dot]
            let rest = line[line.index(after: dot)...]
            guard !prefix.isEmpty,
                  prefix.allSatisfy(\.isNumber),
                  rest.first == " " else {
                return nil
            }
            return (String(prefix), String(rest.dropFirst()))
        }

        private func taskListItem(from item: String) -> (isChecked: Bool, text: String)? {
            guard item.count >= 4 else { return nil }
            let prefix = item.prefix(4).lowercased()
            guard prefix == "[ ] " || prefix == "[x] " else { return nil }
            return (prefix == "[x] ", String(item.dropFirst(4)))
        }

        private func isHorizontalRule(_ line: String) -> Bool {
            let compact = line.filter { !$0.isWhitespace }
            guard compact.count >= 3 else { return false }
            return compact.allSatisfy { $0 == "-" }
                || compact.allSatisfy { $0 == "*" }
                || compact.allSatisfy { $0 == "_" }
        }

        private func shouldContinueParagraph(with line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            return !trimmed.hasPrefix("#")
                && !trimmed.hasPrefix(">")
                && !trimmed.hasPrefix("```")
                && !trimmed.hasPrefix("~~~")
                && !isHorizontalRule(trimmed)
                && unorderedListItem(from: trimmed) == nil
                && orderedListItem(from: trimmed) == nil
                && !isIndentedCode(line)
                && MarkdownPreviewAttributedRenderer.referenceDefinition(from: trimmed) == nil
        }

        private func isIndentedCode(_ line: String) -> Bool {
            line.hasPrefix("    ") || line.hasPrefix("\t")
        }

        private func dropCodeIndent(from line: String) -> String {
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
            return line
        }

        private func trimTrailingBlankLines(from lines: inout [String]) {
            while lines.last?.isEmpty == true {
                lines.removeLast()
            }
        }

        private func tableRows(startingAt startIndex: Int, lines: [String]) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
            guard startIndex + 1 < lines.count else { return nil }

            let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
            let dividerLine = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
            guard headerLine.contains("|"),
                  let headers = tableCells(from: headerLine),
                  isTableDivider(dividerLine, expectedColumnCount: headers.count) else {
                return nil
            }

            var rows: [[String]] = []
            var index = startIndex + 2
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                guard candidate.contains("|"), let cells = tableCells(from: candidate) else { break }
                rows.append(cells)
                index += 1
            }

            return (headers, rows, index)
        }

        private func tableCells(from line: String) -> [String]? {
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") {
                trimmed.removeFirst()
            }
            if trimmed.hasSuffix("|") {
                trimmed.removeLast()
            }

            let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return cells.count > 1 ? cells : nil
        }

        private func isTableDivider(_ line: String, expectedColumnCount: Int) -> Bool {
            guard let cells = tableCells(from: line), cells.count == expectedColumnCount else { return false }
            return cells.allSatisfy { cell in
                let marker = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":-"))
                let dashCount = cell.filter { $0 == "-" }.count
                return marker.isEmpty && dashCount >= 3
            }
        }

        private func normalizedTableCells(_ cells: [String], count: Int) -> [String] {
            if cells.count == count {
                return cells
            }

            if cells.count > count {
                return Array(cells.prefix(count))
            }

            return cells + Array(repeating: "", count: count - cells.count)
        }

        private func columnWidths(for rows: [[String]]) -> [Int] {
            guard let firstRow = rows.first else { return [] }
            return firstRow.indices.map { column in
                rows.map { row in
                    guard column < row.count else { return 0 }
                    return row[column].count
                }.max() ?? 0
            }
        }

        private func boldFont(from attributes: [NSAttributedString.Key: Any]) -> NSFont {
            let font = attributes[.font] as? NSFont ?? baseFont
            return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }

        private func italicFont(from attributes: [NSAttributedString.Key: Any]) -> NSFont {
            let font = attributes[.font] as? NSFont ?? baseFont
            return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        private func parseInlineLinkDestination(_ value: String) -> (url: String, title: String?) {
            guard let quoteIndex = value.firstIndex(of: "\"") else {
                return (value.trimmingCharacters(in: .whitespaces), nil)
            }
            let url = String(value[..<quoteIndex]).trimmingCharacters(in: .whitespaces)
            let title = String(value[quoteIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            return (String(url), title.isEmpty ? nil : String(title))
        }

        private func unescapeMarkdownEscapes(in value: String) -> String {
            value.replacingOccurrences(
                of: #"\\([\\`*_{}\[\]<>\(\)#+\-.!|])"#,
                with: "$1",
                options: .regularExpression
            )
        }

        private func mergedAttributes(
            _ base: [NSAttributedString.Key: Any],
            _ override: [NSAttributedString.Key: Any]
        ) -> [NSAttributedString.Key: Any] {
            base.merging(override) { _, new in new }
        }

        private func trimTrailingNewlines() {
            while result.length > 0, result.string.hasSuffix("\n") {
                result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
            }
        }
    }

    private static func referenceDefinition(from line: String) -> (label: String, reference: MarkdownPreviewLinkReference)? {
        let pattern = #"^\[([^\]]+)\]:\s*<?([^>\s]+)>?(?:\s+(?:"([^"]+)"|'([^']+)'|\(([^)]+)\)))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let source = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: source.length)) else {
            return nil
        }

        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return nil }
            return source.substring(with: range)
        }

        let title = group(3) ?? group(4) ?? group(5)
        return (
            normalizeReferenceLabel(group(1) ?? ""),
            MarkdownPreviewLinkReference(url: group(2) ?? "", title: title)
        )
    }

    private static func normalizeReferenceLabel(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct MarkdownPreviewLinkReference {
        let url: String
        let title: String?
    }

    private struct MarkdownPreviewDocumentParts {
        let contentLines: [String]
        let references: [String: MarkdownPreviewLinkReference]

        init(markdown: String) {
            var references: [String: MarkdownPreviewLinkReference] = [:]
            var contentLines: [String] = []

            for line in markdown.components(separatedBy: .newlines) {
                if let reference = MarkdownPreviewAttributedRenderer.referenceDefinition(from: line.trimmingCharacters(in: .whitespaces)) {
                    references[reference.label] = reference.reference
                } else {
                    contentLines.append(line)
                }
            }

            self.contentLines = contentLines
            self.references = references
        }
    }
}
