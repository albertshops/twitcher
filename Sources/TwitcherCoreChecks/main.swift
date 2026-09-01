import Foundation
import TwitcherCore

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("Check failed: \(message)\n".utf8))
        exit(1)
    }
}

let editor = WindowIdentity(
    bundleIdentifier: "com.example.Editor",
    title: "Notes.txt",
    documentURL: "file:///tmp/Notes.txt"
)

var book = AssignmentBook()
book.assign("N", to: editor)
expect(book.identity(for: "n") == editor, "letter lookup should be case-insensitive")
expect(book.letter(for: editor) == "n", "window lookup should return its letter")

book.assign("e", to: editor)
expect(book.identity(for: "n") == nil, "reassigning a window should release its old letter")
expect(book.identity(for: "e") == editor, "reassigning a window should use its new letter")

let browser = WindowIdentity(bundleIdentifier: "com.example.Browser", title: "Home", documentURL: nil)
book.assign("e", to: browser)
expect(book.identity(for: "e") == browser, "reassigning a letter should replace its old window")
expect(book.letter(for: editor) == nil, "replaced windows should no longer have a letter")

let renamedEditor = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Notes.txt - Edited",
    documentURL: editor.documentURL
)
expect(editor.matches(renamedEditor), "document URLs should survive title changes")
let missingDocument = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: editor.title,
    documentURL: nil
)
expect(!editor.matches(missingDocument), "document-backed assignments should not use a title fallback")

let terminal = WindowIdentity(bundleIdentifier: "com.example.Terminal", title: "Server", documentURL: nil)
expect(terminal.matches(terminal), "titles should match windows without document URLs")

let suite = "TwitcherChecks.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
let store = AssignmentStore(defaults: defaults)
store.save(book)
expect(store.load() == book, "assignment storage should round-trip")
defaults.removePersistentDomain(forName: suite)

print("All TwitcherCore checks passed")
