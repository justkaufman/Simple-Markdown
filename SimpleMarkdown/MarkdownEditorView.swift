import AppKit
import SwiftUI

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.textContainerInset = NSSize(width: 28, height: 28)
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        guard textView.string != text else { return }

        let selectedRange = textView.selectedRange()
        textView.string = text
        textView.setSelectedRange(clampedRange(selectedRange, in: text))
    }

    private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(range.location, length)
        let selectionLength = min(range.length, length - location)
        return NSRange(location: location, length: selectionLength)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

final class MarkdownTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        guard shouldHandleTextInsertion(from: event),
              let typedText = event.charactersIgnoringModifiers,
              typedText.count == 1 else {
            super.keyDown(with: event)
            return
        }

        if handleEmphasisExpansion(for: typedText) {
            return
        }

        if MarkdownAutoPairing.isClosingDelimiter(typedText),
           skipOverClosingDelimiter(typedText) {
            return
        }

        if let closingDelimiter = MarkdownAutoPairing.closingDelimiter(for: typedText) {
            insertPair(openingDelimiter: typedText, closingDelimiter: closingDelimiter)
            return
        }

        super.keyDown(with: event)
    }

    override func deleteBackward(_ sender: Any?) {
        let selectedRange = selectedRange()
        guard selectedRange.length == 0,
              selectedRange.location > 0,
              selectedRange.location < (string as NSString).length else {
            super.deleteBackward(sender)
            return
        }

        let previousRange = NSRange(location: selectedRange.location - 1, length: 1)
        let nextRange = NSRange(location: selectedRange.location, length: 1)
        let previousText = (string as NSString).substring(with: previousRange)
        let nextText = (string as NSString).substring(with: nextRange)

        guard MarkdownAutoPairing.closingDelimiter(for: previousText) == nextText else {
            super.deleteBackward(sender)
            return
        }

        replaceText(in: NSRange(location: selectedRange.location - 1, length: 2), with: "", selectedRange: previousRange)
    }

    private func shouldHandleTextInsertion(from event: NSEvent) -> Bool {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        return event.modifierFlags.intersection(blockedModifiers).isEmpty
    }

    private func insertPair(openingDelimiter: String, closingDelimiter: String) {
        let range = selectedRange()
        let selectedText = (string as NSString).substring(with: range)
        let replacement = "\(openingDelimiter)\(selectedText)\(closingDelimiter)"
        let newSelection = NSRange(location: range.location + openingDelimiter.count, length: range.length)

        replaceText(in: range, with: replacement, selectedRange: newSelection)
    }

    private func handleEmphasisExpansion(for typedText: String) -> Bool {
        guard MarkdownAutoPairing.isEmphasisDelimiter(typedText) else { return false }

        let range = selectedRange()
        let nsString = string as NSString
        guard range.length == 0,
              range.location > 0,
              range.location < nsString.length else {
            return false
        }

        let previousText = nsString.substring(with: NSRange(location: range.location - 1, length: 1))
        let nextText = nsString.substring(with: NSRange(location: range.location, length: 1))
        guard previousText == typedText, nextText == typedText else { return false }

        let replacement = String(repeating: typedText, count: 4)
        let replacementRange = NSRange(location: range.location - 1, length: 2)
        let newSelection = NSRange(location: range.location + 1, length: 0)
        replaceText(in: replacementRange, with: replacement, selectedRange: newSelection)
        return true
    }

    private func skipOverClosingDelimiter(_ typedText: String) -> Bool {
        let range = selectedRange()
        let nsString = string as NSString
        guard range.length == 0,
              range.location < nsString.length else {
            return false
        }

        let nextText = nsString.substring(with: NSRange(location: range.location, length: 1))
        guard nextText == typedText else { return false }

        setSelectedRange(NSRange(location: range.location + 1, length: 0))
        return true
    }

    private func replaceText(in range: NSRange, with replacement: String, selectedRange: NSRange) {
        guard shouldChangeText(in: range, replacementString: replacement) else { return }

        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRange(selectedRange)
    }
}
