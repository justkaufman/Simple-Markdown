import Foundation

enum MarkdownRenderer {
    static func htmlDocument(from markdown: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root {
            color-scheme: light dark;
            --background: #ffffff;
            --body: #1f2328;
            --muted: #57606a;
            --border: #d0d7de;
            --code-bg: #f6f8fa;
            --link: #0969da;
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --background: #0d1117;
                --body: #e6edf3;
                --muted: #8b949e;
                --border: #30363d;
                --code-bg: #161b22;
                --link: #58a6ff;
            }
        }

        html {
            background: var(--background);
            min-height: 100%;
        }

        body {
            background: var(--background);
            box-sizing: border-box;
            color: var(--body);
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", Helvetica, Arial, sans-serif;
            font-size: 15px;
            line-height: 1.58;
            margin: 0 auto;
            max-width: 840px;
            min-height: 100vh;
            padding: 32px;
        }

        h1, h2, h3, h4, h5, h6 {
            line-height: 1.2;
            margin: 1.4em 0 0.55em;
        }

        h1, h2 {
            border-bottom: 1px solid var(--border);
            padding-bottom: 0.25em;
        }

        a { color: var(--link); }
        blockquote {
            border-left: 4px solid var(--border);
            color: var(--muted);
            margin: 1em 0;
            padding: 0 1em;
        }

        code, pre {
            background: var(--code-bg);
            border-radius: 6px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        }

        code { padding: 0.15em 0.35em; }
        pre {
            overflow-x: auto;
            padding: 16px;
        }

        pre code {
            background: transparent;
            padding: 0;
        }

        hr {
            border: 0;
            border-top: 1px solid var(--border);
            margin: 24px 0;
        }

        table {
            border-collapse: collapse;
            margin: 1em 0;
            width: 100%;
        }

        th, td {
            border: 1px solid var(--border);
            padding: 6px 10px;
            text-align: left;
        }

        th {
            background: var(--code-bg);
            font-weight: 600;
        }

        img {
            height: auto;
            max-width: 100%;
        }

        input[type="checkbox"] {
            margin-right: 0.45em;
        }

        mark {
            background: #fff3a3;
            border-radius: 3px;
            color: inherit;
            padding: 0 0.15em;
        }
        </style>
        </head>
        <body>
        \(bodyHTML(from: markdown))
        </body>
        </html>
        """
    }

    static func bodyHTML(from markdown: String) -> String {
        let document = MarkdownDocumentParts(markdown: markdown)
        let lines = document.contentLines
        var html: [String] = []
        var listStack: [ListKind] = []
        var isInFence = false
        var fenceLines: [String] = []
        var index = 0

        func closeLists(to depth: Int = 0) {
            while listStack.count > depth {
                html.append("</\(listStack.removeLast().rawValue)>")
            }
        }

        func openList(_ kind: ListKind, at depth: Int) {
            closeLists(to: depth)
            if listStack.count == depth, listStack.last != kind {
                closeLists(to: depth - 1)
            }
            while listStack.count < depth {
                html.append("<\(kind.rawValue)>")
                listStack.append(kind)
            }
            if listStack.last != kind {
                closeLists(to: depth - 1)
                html.append("<\(kind.rawValue)>")
                listStack.append(kind)
            }
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            index += 1

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if isInFence {
                    html.append("<pre><code>\(escapeHTML(fenceLines.joined(separator: "\n")))</code></pre>")
                    fenceLines = []
                    isInFence = false
                } else {
                    closeLists()
                    isInFence = true
                }
                continue
            }

            if isInFence {
                fenceLines.append(line)
                continue
            }

            if trimmed.isEmpty {
                closeLists()
                continue
            }

            if isIndentedCode(line) {
                closeLists()
                var codeLines = [dropCodeIndent(from: line)]
                while index < lines.count, lines[index].isEmpty || isIndentedCode(lines[index]) {
                    let codeLine = lines[index]
                    codeLines.append(codeLine.isEmpty ? "" : dropCodeIndent(from: codeLine))
                    index += 1
                }
                trimTrailingBlankLines(from: &codeLines)
                html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                continue
            }

            if let table = tableHTML(startingAt: index - 1, lines: lines, references: document.references) {
                closeLists()
                html.append(table.html)
                index = table.nextIndex
                continue
            }

            if let setext = setextHeadingHTML(startingAt: index - 1, lines: lines, references: document.references) {
                closeLists()
                html.append(setext.html)
                index = setext.nextIndex
                continue
            }

            if let heading = headingHTML(from: trimmed, references: document.references) {
                closeLists()
                html.append(heading)
            } else if isHorizontalRule(trimmed) {
                closeLists()
                html.append("<hr>")
            } else if let quote = blockquoteHTML(from: trimmed, references: document.references) {
                closeLists()
                html.append(quote)
            } else if let item = listItem(from: line) {
                openList(item.kind, at: item.depth)
                html.append("<li>\(listItemHTML(from: item.text, references: document.references))</li>")
            } else {
                closeLists()
                var paragraphLines = [line]
                while index < lines.count, shouldContinueParagraph(with: lines[index]) {
                    paragraphLines.append(lines[index])
                    index += 1
                }
                html.append("<p>\(paragraphHTML(from: paragraphLines, references: document.references))</p>")
            }
        }

        if isInFence {
            html.append("<pre><code>\(escapeHTML(fenceLines.joined(separator: "\n")))</code></pre>")
        }
        closeLists()

        return html.joined(separator: "\n")
    }

    private static func headingHTML(from line: String, references: [String: LinkReference]) -> String? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes),
              line.dropFirst(hashes).first == " " else {
            return nil
        }

        let text = line.dropFirst(hashes + 1)
        return "<h\(hashes)>\(inlineHTML(from: String(text), references: references))</h\(hashes)>"
    }

    private static func setextHeadingHTML(
        startingAt startIndex: Int,
        lines: [String],
        references: [String: LinkReference]
    ) -> (html: String, nextIndex: Int)? {
        guard startIndex + 1 < lines.count else { return nil }
        let text = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let marker = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if marker.allSatisfy({ $0 == "=" }), marker.count >= 2 {
            return ("<h1>\(inlineHTML(from: text, references: references))</h1>", startIndex + 2)
        }
        if marker.allSatisfy({ $0 == "-" }), marker.count >= 2 {
            return ("<h2>\(inlineHTML(from: text, references: references))</h2>", startIndex + 2)
        }
        return nil
    }

    private static func blockquoteHTML(from line: String, references: [String: LinkReference]) -> String? {
        guard line.hasPrefix(">") else { return nil }
        let quoteDepth = line.prefix(while: { $0 == ">" }).count
        let text = line.dropFirst(quoteDepth).trimmingCharacters(in: .whitespaces)
        let content = text.isEmpty ? "" : inlineHTML(from: text, references: references)
        return String(repeating: "<blockquote>", count: quoteDepth)
            + content
            + String(repeating: "</blockquote>", count: quoteDepth)
    }

    private static func listItem(from line: String) -> (kind: ListKind, depth: Int, text: String)? {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let depth = leadingSpaces / 4 + 1
        let trimmed = String(line.dropFirst(leadingSpaces))

        if trimmed.count > 2 {
            let marker = trimmed.prefix(2)
            if marker == "- " || marker == "* " || marker == "+ " {
                return (.unordered, depth, String(trimmed.dropFirst(2)))
            }
        }

        guard let dot = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = trimmed[..<dot]
        let rest = trimmed[trimmed.index(after: dot)...]
        guard !prefix.isEmpty,
              prefix.allSatisfy(\.isNumber),
              rest.first == " " else {
            return nil
        }
        return (.ordered, depth, String(rest.dropFirst()))
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" }
            || compact.allSatisfy { $0 == "*" }
            || compact.allSatisfy { $0 == "_" }
    }

    private static func paragraphHTML(from lines: [String], references: [String: LinkReference]) -> String {
        lines.enumerated().map { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let breakTag = line.hasSuffix("  ") || trimmed.hasSuffix("<br>") ? "<br>" : nil
            let text = trimmed.hasSuffix("<br>") ? String(trimmed.dropLast(4)) : trimmed
            if index == lines.count - 1 {
                return inlineHTML(from: text, references: references)
            }
            return inlineHTML(from: text, references: references) + (breakTag ?? " ")
        }.joined()
    }

    private static func inlineHTML(from text: String, references: [String: LinkReference]) -> String {
        var html = escapeHTML(text)
        html = unescapeMarkdownEscapes(in: html)
        html = replace(pattern: #"``([^`]+(?:`[^`]+)*)``"#, in: html) { match in
            "<code>\(match[1])</code>"
        }
        html = replace(pattern: #"`([^`]+)`"#, in: html) { match in
            "<code>\(match[1])</code>"
        }
        html = replace(pattern: #"\[!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)\]\(([^)]+)\)"#, in: html) { match in
            let title = match[3].isEmpty ? "" : " title=\"\(match[3])\""
            return "<a href=\"\(match[4])\"><img src=\"\(match[2])\" alt=\"\(match[1])\"\(title)></a>"
        }
        html = replace(pattern: #"\!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;([^&]*)&quot;)?\)"#, in: html) { match in
            let title = match[3].isEmpty ? "" : " title=\"\(match[3])\""
            return "<img src=\"\(match[2])\" alt=\"\(match[1])\"\(title)>"
        }
        html = replace(pattern: #"\[([^\]]+)\]\((\S+?)(?:\s+&quot;([^&]*)&quot;)?\)"#, in: html) { match in
            let title = match[3].isEmpty ? "" : " title=\"\(match[3])\""
            return "<a href=\"\(match[2])\"\(title)>\(match[1])</a>"
        }
        html = replace(pattern: #"\[([^\]]+)\]\s?\[([^\]]+)\]"#, in: html) { match in
            guard let reference = references[normalizeReferenceLabel(match[2])] else { return match[0] }
            let title = reference.title.map { " title=\"\($0)\"" } ?? ""
            return "<a href=\"\(reference.url)\"\(title)>\(match[1])</a>"
        }
        html = replace(pattern: #"&lt;(https?://[^&\s]+)&gt;"#, in: html) { match in
            "<a href=\"\(match[1])\">\(match[1])</a>"
        }
        html = replace(pattern: #"&lt;([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})&gt;"#, options: [.caseInsensitive], in: html) { match in
            "<a href=\"mailto:\(match[1])\">\(match[1])</a>"
        }
        html = replace(pattern: #"\*\*\*([^*]+)\*\*\*"#, in: html) { match in
            "<strong><em>\(match[1])</em></strong>"
        }
        html = replace(pattern: #"___([^_]+)___"#, in: html) { match in
            "<strong><em>\(match[1])</em></strong>"
        }
        html = replace(pattern: #"~~([^~]+)~~"#, in: html) { match in
            "<s>\(match[1])</s>"
        }
        html = replace(pattern: #"==([^=]+)=="#, in: html) { match in
            "<mark>\(match[1])</mark>"
        }
        html = replace(pattern: #"(?<![=\w])=([^=\n]+)=(?![=\w])"#, in: html) { match in
            "<mark>\(match[1])</mark>"
        }
        html = replace(pattern: #"\*\*([^*]+)\*\*"#, in: html) { match in
            "<strong>\(match[1])</strong>"
        }
        html = replace(pattern: #"__([^_]+)__"#, in: html) { match in
            "<strong>\(match[1])</strong>"
        }
        html = replace(pattern: #"\*([^*]+)\*"#, in: html) { match in
            "<em>\(match[1])</em>"
        }
        html = replace(pattern: #"_([^_]+)_"#, in: html) { match in
            "<em>\(match[1])</em>"
        }
        html = html.replacingOccurrences(of: "&lt;br&gt;", with: "<br>")
        return html
    }

    private static func listItemHTML(from item: String, references: [String: LinkReference]) -> String {
        if let task = taskListItem(from: item) {
            let checked = task.isChecked ? " checked" : ""
            return "<input type=\"checkbox\" disabled\(checked)> \(inlineHTML(from: task.text, references: references))"
        }
        return inlineHTML(from: item, references: references)
    }

    private static func taskListItem(from item: String) -> (isChecked: Bool, text: String)? {
        guard item.count >= 4 else { return nil }
        let prefix = item.prefix(4).lowercased()
        guard prefix == "[ ] " || prefix == "[x] " else { return nil }
        return (prefix == "[x] ", String(item.dropFirst(4)))
    }

    private static func tableHTML(
        startingAt startIndex: Int,
        lines: [String],
        references: [String: LinkReference]
    ) -> (html: String, nextIndex: Int)? {
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

        let headerHTML = headers
            .map { "<th>\(inlineHTML(from: $0, references: references))</th>" }
            .joined()
        let bodyHTML = rows
            .map { row in
                let cells = normalizedTableCells(row, count: headers.count)
                    .map { "<td>\(inlineHTML(from: $0, references: references))</td>" }
                    .joined()
                return "<tr>\(cells)</tr>"
            }
            .joined(separator: "\n")

        let table = """
        <table>
        <thead><tr>\(headerHTML)</tr></thead>
        <tbody>
        \(bodyHTML)
        </tbody>
        </table>
        """

        return (table, index)
    }

    private static func shouldContinueParagraph(with line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return !trimmed.hasPrefix("#")
            && !trimmed.hasPrefix(">")
            && !trimmed.hasPrefix("```")
            && !trimmed.hasPrefix("~~~")
            && !isHorizontalRule(trimmed)
            && listItem(from: line) == nil
            && !isIndentedCode(line)
            && referenceDefinition(from: trimmed) == nil
    }

    private static func isIndentedCode(_ line: String) -> Bool {
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    private static func dropCodeIndent(from line: String) -> String {
        if line.hasPrefix("\t") { return String(line.dropFirst()) }
        if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
        return line
    }

    private static func trimTrailingBlankLines(from lines: inout [String]) {
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
    }

    private static func tableCells(from line: String) -> [String]? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { unescapeMarkdownEscapes(in: $0.trimmingCharacters(in: .whitespaces)) }
        return cells.count > 1 ? cells : nil
    }

    private static func isTableDivider(_ line: String, expectedColumnCount: Int) -> Bool {
        guard let cells = tableCells(from: line), cells.count == expectedColumnCount else { return false }
        return cells.allSatisfy { cell in
            let marker = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":-"))
            let dashCount = cell.filter { $0 == "-" }.count
            return marker.isEmpty && dashCount >= 3
        }
    }

    private static func normalizedTableCells(_ cells: [String], count: Int) -> [String] {
        if cells.count == count {
            return cells
        }

        if cells.count > count {
            return Array(cells.prefix(count))
        }

        return cells + Array(repeating: "", count: count - cells.count)
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func unescapeMarkdownEscapes(in value: String) -> String {
        value.replacingOccurrences(
            of: #"\\([\\`*_{}\[\]<>\(\)#+\-.!|])"#,
            with: "$1",
            options: .regularExpression
        )
    }

    private static func replace(
        pattern: String,
        options: NSRegularExpression.Options = [],
        in value: String,
        transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return value }

        let source = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return value }

        var result = value
        for match in matches.reversed() {
            let groups = (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return "" }
                return source.substring(with: range)
            }
            let replacement = transform(groups)
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }

    private static func referenceDefinition(from line: String) -> (label: String, reference: LinkReference)? {
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
            LinkReference(url: escapeHTML(group(2) ?? ""), title: title.map(escapeHTML))
        )
    }

    private static func normalizeReferenceLabel(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private enum ListKind: String {
        case unordered = "ul"
        case ordered = "ol"
    }

    private struct LinkReference {
        let url: String
        let title: String?
    }

    private struct MarkdownDocumentParts {
        let contentLines: [String]
        let references: [String: LinkReference]

        init(markdown: String) {
            var references: [String: LinkReference] = [:]
            var contentLines: [String] = []

            for line in markdown.components(separatedBy: .newlines) {
                if let reference = MarkdownRenderer.referenceDefinition(from: line.trimmingCharacters(in: .whitespaces)) {
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
