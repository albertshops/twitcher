import Foundation
import TwitcherCore

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("Check failed: \(message)\n".utf8))
        exit(1)
    }
}

private func temporaryDefaults() -> (UserDefaults, String) {
    let suite = "TwitcherChecks.\(UUID().uuidString)"
    return (UserDefaults(suiteName: suite)!, suite)
}

let editor = ProgramIdentity(bundleIdentifier: "com.example.Editor", name: "Editor")
let editorTarget = AssignmentTarget.program(editor)
let notes = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Notes",
    documentURL: "file:///tmp/Notes.txt"
)
let notesTarget = AssignmentTarget.window(notes)

var book = AssignmentBook()
book.assign("N", to: editorTarget)
expect(book.target(for: "n") == editorTarget, "letter lookup should be case-insensitive")
expect(book.letter(for: editorTarget) == "n", "program lookup should return its letter")

book.assign("e", to: editorTarget)
expect(book.target(for: "n") == nil, "reassigning a program should release its old letter")
expect(book.target(for: "e") == editorTarget, "reassigning a program should use its new letter")

book.assign("n", to: notesTarget)
expect(book.target(for: "e") == editorTarget, "program and window assignments should coexist")
expect(book.target(for: "n") == notesTarget, "a window should have its own assignment")
expect(book.windowIdentities(for: editor) == [notes], "program cycling should find its assigned windows")

let movedNotes = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Renamed Notes",
    documentURL: notes.documentURL
)
expect(notes.matches(movedNotes), "document URLs should survive window title changes")
let untitled = WindowIdentity(bundleIdentifier: editor.bundleIdentifier, title: "Scratch", documentURL: nil)
let sameUntitled = WindowIdentity(bundleIdentifier: editor.bundleIdentifier, title: "Scratch", documentURL: nil)
expect(untitled.matches(sameUntitled), "windows without documents should match by title")
let firstScratch = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Scratch",
    documentURL: nil,
    windowNumber: 10
)
let secondScratch = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Scratch",
    documentURL: nil,
    windowNumber: 11
)
expect(!firstScratch.matches(secondScratch), "live windows with the same title should remain distinct")
expect(firstScratch.matchesPersistedProperties(secondScratch), "saved window matching should retain the title fallback")
let renamedScratch = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Another Folder",
    documentURL: nil,
    windowNumber: firstScratch.windowNumber
)
expect(firstScratch.matches(renamedScratch), "a live window ID should survive title changes")

let browser = ProgramIdentity(bundleIdentifier: "com.example.Browser", name: "Browser")
let browserTarget = AssignmentTarget.program(browser)
book.assign("e", to: browserTarget)
expect(book.target(for: "e") == browserTarget, "reassigning a letter should replace its old target")
expect(book.letter(for: editorTarget) == nil, "replaced programs should no longer have a letter")
expect(book.letter(for: notesTarget) == "n", "replacing a program shortcut should not remove its window shortcuts")

let renamedEditor = ProgramIdentity(bundleIdentifier: editor.bundleIdentifier, name: "Renamed Editor")
expect(editor.matches(renamedEditor), "bundle identifiers should survive program name changes")
expect(!editor.matches(browser), "different bundle identifiers should not match")

let (defaults, suite) = temporaryDefaults()
defer { defaults.removePersistentDomain(forName: suite) }
let store = AssignmentStore(defaults: defaults)
store.save(book)
expect(store.load() == book, "mixed assignment storage should round-trip")

struct PreviousProgramBook: Encodable {
    let assignments: [String: ProgramIdentity]
}

let (programDefaults, programSuite) = temporaryDefaults()
defer { programDefaults.removePersistentDomain(forName: programSuite) }
programDefaults.set(
    try JSONEncoder().encode(PreviousProgramBook(assignments: ["e": editor])),
    forKey: "programAssignments"
)
let migratedPrograms = AssignmentStore(defaults: programDefaults).load()
expect(migratedPrograms.target(for: "e") == editorTarget, "existing program assignments should migrate")

struct PreviousWindowBook: Encodable {
    let assignments: [String: WindowIdentity]
}

let (windowDefaults, windowSuite) = temporaryDefaults()
defer { windowDefaults.removePersistentDomain(forName: windowSuite) }
let otherNotes = WindowIdentity(
    bundleIdentifier: editor.bundleIdentifier,
    title: "Other Notes",
    documentURL: "file:///tmp/Other.txt"
)
windowDefaults.set(
    try JSONEncoder().encode(PreviousWindowBook(assignments: ["e": notes, "n": otherNotes])),
    forKey: "windowAssignments"
)
let migratedWindows = AssignmentStore(defaults: windowDefaults).load()
expect(migratedWindows.target(for: "e") == notesTarget, "legacy window assignments should migrate")
expect(
    migratedWindows.target(for: "n") == .window(otherNotes),
    "multiple legacy windows from one program should be retained"
)

print("All TwitcherCore checks passed")
