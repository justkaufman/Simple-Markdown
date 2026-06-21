import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var mode: MarkdownMode = .split

    var body: some View {
        Group {
            switch mode {
            case .edit:
                editor
            case .preview:
                MarkdownPreviewView(markdown: document.text)
            case .split:
                HSplitView {
                    editor
                        .frame(minWidth: 320)
                    MarkdownPreviewView(markdown: document.text)
                        .frame(minWidth: 320)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Mode", selection: $mode) {
                    ForEach(MarkdownMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
        }
    }

    private var editor: some View {
        MarkdownEditorView(text: $document.text)
            .background(Color(nsColor: .textBackgroundColor))
    }
}
