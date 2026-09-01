import Foundation

public struct WindowIdentity: Codable, Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let title: String
    public let documentURL: String?

    public init(bundleIdentifier: String, title: String, documentURL: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.documentURL = documentURL
    }

    public func matches(_ candidate: WindowIdentity) -> Bool {
        guard bundleIdentifier == candidate.bundleIdentifier else { return false }
        if let documentURL {
            return documentURL == candidate.documentURL
        }
        return title == candidate.title
    }
}

public struct AssignmentBook: Codable, Equatable, Sendable {
    public private(set) var assignments: [String: WindowIdentity]

    public init(assignments: [String: WindowIdentity] = [:]) {
        self.assignments = assignments
    }

    public mutating func assign(_ letter: Character, to window: WindowIdentity) {
        let key = String(letter).lowercased()
        guard key.count == 1, key.first?.isASCII == true, key.first?.isLetter == true else { return }

        assignments = assignments.filter { !$0.value.matches(window) }
        assignments[key] = window
    }

    public mutating func remove(letter: Character) {
        assignments.removeValue(forKey: String(letter).lowercased())
    }

    public mutating func remove(window: WindowIdentity) {
        assignments = assignments.filter { !$0.value.matches(window) }
    }

    public func letter(for window: WindowIdentity) -> Character? {
        assignments.first { $0.value.matches(window) }?.key.first
    }

    public func identity(for letter: Character) -> WindowIdentity? {
        assignments[String(letter).lowercased()]
    }
}

public final class AssignmentStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "windowAssignments") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AssignmentBook {
        guard let data = defaults.data(forKey: key),
              let book = try? JSONDecoder().decode(AssignmentBook.self, from: data)
        else { return AssignmentBook() }
        return book
    }

    public func save(_ book: AssignmentBook) {
        guard let data = try? JSONEncoder().encode(book) else { return }
        defaults.set(data, forKey: key)
    }
}
