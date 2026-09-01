import Foundation
import TwitcherCore

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("Check failed: \(message)\n".utf8))
        exit(1)
    }
}

let editor = ProgramIdentity(bundleIdentifier: "com.example.Editor", name: "Editor")

var book = AssignmentBook()
book.assign("N", to: editor)
expect(book.identity(for: "n") == editor, "letter lookup should be case-insensitive")
expect(book.letter(for: editor) == "n", "program lookup should return its letter")

book.assign("e", to: editor)
expect(book.identity(for: "n") == nil, "reassigning a program should release its old letter")
expect(book.identity(for: "e") == editor, "reassigning a program should use its new letter")

let browser = ProgramIdentity(bundleIdentifier: "com.example.Browser", name: "Browser")
book.assign("e", to: browser)
expect(book.identity(for: "e") == browser, "reassigning a letter should replace its old program")
expect(book.letter(for: editor) == nil, "replaced programs should no longer have a letter")

let renamedEditor = ProgramIdentity(bundleIdentifier: editor.bundleIdentifier, name: "Renamed Editor")
expect(editor.matches(renamedEditor), "bundle identifiers should survive program name changes")
expect(!editor.matches(browser), "different bundle identifiers should not match")

let suite = "TwitcherChecks.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let store = AssignmentStore(defaults: defaults)
store.save(book)
expect(store.load() == book, "assignment storage should round-trip")

defaults.removeObject(forKey: "programAssignments")
let legacy: [String: Any] = [
    "assignments": [
        "b": ["bundleIdentifier": browser.bundleIdentifier, "title": "Home"],
        "e": ["bundleIdentifier": editor.bundleIdentifier, "title": "Notes"],
        "n": ["bundleIdentifier": editor.bundleIdentifier, "title": "Other Notes"],
    ],
]
defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "windowAssignments")
let migrated = store.load()
expect(migrated.assignments.count == 2, "migration should keep one shortcut per program")
expect(migrated.identity(for: "b")?.bundleIdentifier == browser.bundleIdentifier, "migration should retain browser assignments")
expect(migrated.identity(for: "e")?.bundleIdentifier == editor.bundleIdentifier, "migration should retain the first editor assignment")
expect(migrated.identity(for: "n") == nil, "migration should discard duplicate program assignments")

print("All TwitcherCore checks passed")
