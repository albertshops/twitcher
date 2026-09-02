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

public struct WindowIdentity: Codable, Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let title: String
    public let documentURL: String?
    public let windowNumber: Int?

    public init(bundleIdentifier: String, title: String, documentURL: String?, windowNumber: Int? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.documentURL = documentURL
        self.windowNumber = windowNumber
    }

    public func matches(_ candidate: WindowIdentity) -> Bool {
        guard bundleIdentifier == candidate.bundleIdentifier else { return false }
        if let windowNumber, let candidateWindowNumber = candidate.windowNumber {
            return windowNumber == candidateWindowNumber
        }
        return matchesPersistedProperties(candidate)
    }

    public func matchesPersistedProperties(_ candidate: WindowIdentity) -> Bool {
        guard bundleIdentifier == candidate.bundleIdentifier else { return false }
        if let documentURL {
            return documentURL == candidate.documentURL
        }
        return title == candidate.title
    }
}

public enum AssignmentTarget: Codable, Equatable, Hashable, Sendable {
    case program(ProgramIdentity)
    case window(WindowIdentity)

    private enum CodingKeys: String, CodingKey {
        case type
        case program
        case window
    }

    private enum TargetType: String, Codable {
        case program
        case window
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(TargetType.self, forKey: .type) {
        case .program:
            self = .program(try container.decode(ProgramIdentity.self, forKey: .program))
        case .window:
            self = .window(try container.decode(WindowIdentity.self, forKey: .window))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .program(identity):
            try container.encode(TargetType.program, forKey: .type)
            try container.encode(identity, forKey: .program)
        case let .window(identity):
            try container.encode(TargetType.window, forKey: .type)
            try container.encode(identity, forKey: .window)
        }
    }

    public func matches(_ candidate: AssignmentTarget) -> Bool {
        switch (self, candidate) {
        case let (.program(identity), .program(candidateIdentity)):
            identity.matches(candidateIdentity)
        case let (.window(identity), .window(candidateIdentity)):
            identity.matches(candidateIdentity)
        default:
            false
        }
    }
}

public struct AssignmentBook: Codable, Equatable, Sendable {
    public private(set) var assignments: [String: AssignmentTarget]

    public init(assignments: [String: AssignmentTarget] = [:]) {
        self.assignments = assignments
    }

    public mutating func assign(_ letter: Character, to target: AssignmentTarget) {
        let key = String(letter).lowercased()
        guard key.count == 1, key.first?.isASCII == true, key.first?.isLetter == true else { return }

        assignments = assignments.filter { !$0.value.matches(target) }
        assignments[key] = target
    }

    public mutating func remove(letter: Character) {
        assignments.removeValue(forKey: String(letter).lowercased())
    }

    public mutating func remove(target: AssignmentTarget) {
        assignments = assignments.filter { !$0.value.matches(target) }
    }

    public func letter(for target: AssignmentTarget) -> Character? {
        assignments.first { $0.value.matches(target) }?.key.first
    }

    public func target(for letter: Character) -> AssignmentTarget? {
        assignments[String(letter).lowercased()]
    }

    public func windowIdentities(for program: ProgramIdentity) -> [WindowIdentity] {
        assignments.values.compactMap { target in
            guard case let .window(identity) = target,
                  identity.bundleIdentifier == program.bundleIdentifier
            else { return nil }
            return identity
        }
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
        if let data = defaults.data(forKey: key) {
            if let book = try? JSONDecoder().decode(AssignmentBook.self, from: data) {
                return book
            }
            if let legacy = try? JSONDecoder().decode(LegacyProgramBook.self, from: data) {
                let book = AssignmentBook(assignments: legacy.assignments.mapValues(AssignmentTarget.program))
                save(book)
                return book
            }
        }
        return migrateLegacyWindowAssignments()
    }

    public func save(_ book: AssignmentBook) {
        guard let data = try? JSONEncoder().encode(book) else { return }
        defaults.set(data, forKey: key)
    }

    private func migrateLegacyWindowAssignments() -> AssignmentBook {
        guard let data = defaults.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(LegacyWindowBook.self, from: data)
        else { return AssignmentBook() }

        let book = AssignmentBook(assignments: legacy.assignments.mapValues(AssignmentTarget.window))
        save(book)
        return book
    }
}

private struct LegacyProgramBook: Decodable {
    let assignments: [String: ProgramIdentity]
}

private struct LegacyWindowBook: Decodable {
    let assignments: [String: WindowIdentity]
}
