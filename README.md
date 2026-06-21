# Simple Markdown

Simple Markdown is a native macOS Markdown editor and previewer built with SwiftUI.

The MVP goal is intentionally small: open any Markdown file, edit it, preview it, and save it without creating a vault, workspace, or project.

## Download

Download the latest app build:

[Download SimpleMarkdown.zip](dist/releases/SimpleMarkdown.zip)

Unzip the file, then drag `SimpleMarkdown.app` into your Applications folder.

## MVP Features

- Open `.md`, `.markdown`, and `.txt` files
- Edit Markdown in a native text editor
- Preview rendered Markdown
- Switch between edit, preview, and split modes
- Save changes back to the original file
- Open multiple files in separate document windows
- Use the macOS sandbox with user-selected read/write access

## Build

Open `SimpleMarkdown.xcodeproj` in Xcode and run the `SimpleMarkdown` scheme.

From Terminal:

```sh
xcodebuild -project SimpleMarkdown.xcodeproj -scheme SimpleMarkdown -destination 'platform=macOS' build
```

## Build a ZIP

Create a Release build and package it as a ZIP containing `SimpleMarkdown.app`:

```sh
./scripts/build-zip.sh
```

The generated ZIP is written to `dist/releases/SimpleMarkdown.zip`.

## Roadmap

- Native Quick Look extension for Finder previews
- Better editor syntax highlighting
- Export to HTML and PDF
- Custom preview CSS
- Find and replace
- Drag-and-drop images
