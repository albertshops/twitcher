import Foundation

public struct ProgramIdentity: Codable, Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let name: String

    public init(bundleIdentifier: String, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    public func matches(_ candidate: ProgramIdentity) -> Bool {
        bundleIdentifier == candidate.bundleIdentifier
    }
}

public struct AssignmentBook: Codable, Equatable, Sendable {
    public private(set) var assignments: [String: ProgramIdentity]

    public init(assignments: [String: ProgramIdentity] = [:]) {
        self.assignments = assignments
    }

    public mutating func assign(_ letter: Character, to program: ProgramIdentity) {
        let key = String(letter).lowercased()
        guard key.count == 1, key.first?.isASCII == true, key.first?.isLetter == true else { return }

        assignments = assignments.filter { !$0.value.matches(program) }
        assignments[key] = program
    }

    public mutating func remove(letter: Character) {
        assignments.removeValue(forKey: String(letter).lowercased())
    }

    public mutating func remove(program: ProgramIdentity) {
        assignments = assignments.filter { !$0.value.matches(program) }
    }

    public func letter(for program: ProgramIdentity) -> Character? {
        assignments.first { $0.value.matches(program) }?.key.first
    }

    public func identity(for letter: Character) -> ProgramIdentity? {
        assignments[String(letter).lowercased()]
    }
}

public final class AssignmentStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let legacyKey: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "programAssignments",
        legacyKey: String = "windowAssignments"
    ) {
        self.defaults = defaults
        self.key = key
        self.legacyKey = legacyKey
    }

    public func load() -> AssignmentBook {
        if let data = defaults.data(forKey: key),
           let book = try? JSONDecoder().decode(AssignmentBook.self, from: data) {
            return book
        }
        return migrateLegacyAssignments()
    }

    public func save(_ book: AssignmentBook) {
        guard let data = try? JSONEncoder().encode(book) else { return }
        defaults.set(data, forKey: key)
    }

    private func migrateLegacyAssignments() -> AssignmentBook {
        struct LegacyWindow: Decodable {
            let bundleIdentifier: String
        }
        struct LegacyBook: Decodable {
            let assignments: [String: LegacyWindow]
        }

        guard let data = defaults.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(LegacyBook.self, from: data)
        else { return AssignmentBook() }

        var seenBundles = Set<String>()
        var migrated: [String: ProgramIdentity] = [:]
        for (letter, window) in legacy.assignments.sorted(by: { $0.key < $1.key }) {
            guard seenBundles.insert(window.bundleIdentifier).inserted else { continue }
            migrated[letter] = ProgramIdentity(
                bundleIdentifier: window.bundleIdentifier,
                name: window.bundleIdentifier
            )
        }

        let book = AssignmentBook(assignments: migrated)
        save(book)
        return book
    }
}
