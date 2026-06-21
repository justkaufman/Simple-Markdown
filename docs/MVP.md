# Simple Markdown MVP

## Product Promise

Open any Markdown file, edit it, preview it, and save it without creating a vault or workspace.

## Current MVP Scope

- Document-based macOS app
- SwiftUI editor
- WebKit preview pane
- Edit, preview, and split modes
- Local Markdown-to-HTML renderer
- Markdown and plain text file support
- User-selected read/write sandbox entitlement
- Unit tests for renderer behavior

## Next Milestones

1. Add a real app icon and asset catalog.
2. Add keyboard shortcuts for edit, preview, and split mode.
3. Improve Markdown rendering for tables, task lists, and nested lists.
4. Add editor find and replace.
5. Add a Quick Look extension for Finder spacebar previews.
6. Prepare distribution builds with signing, notarization, and release packaging.

## Distribution Path

The app can ship first as a signed and notarized direct download from a website. App Store distribution should come after the MVP is stable, because it requires Apple Developer account setup, bundle ID registration, signing certificates, and App Store metadata.

