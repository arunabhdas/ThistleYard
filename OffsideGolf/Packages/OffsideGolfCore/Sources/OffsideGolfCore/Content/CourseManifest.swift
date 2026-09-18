import Foundation

public struct HoleSummary: Decodable, Hashable, Sendable, Identifiable {
    public let id: String
    public let number: Int
    public let name: String
    public let par: Int
    public let distanceYards: Int
    public let summary: String
    public let landmark: String
}

public struct CourseManifest: Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let contentVersion: Int
    public let holes: [HoleSummary]

    public var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
    public var totalDistanceYards: Int { holes.reduce(0) { $0 + $1.distanceYards } }

    public static func decode(_ data: Data) throws -> CourseManifest {
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.schemaVersion == 1 else {
            throw CourseManifestError.unsupportedSchema(document.schemaVersion)
        }
        guard document.contentVersion > 0,
              [document.id, document.name, document.summary].allSatisfy(Self.hasText) else {
            throw CourseManifestError.invalidMetadata
        }
        guard document.holes.count == 9 else { throw CourseManifestError.invalidHoleCount }
        guard Set(document.holes.map(\.id)).count == document.holes.count else {
            throw CourseManifestError.duplicateHoleID
        }
        guard document.holes.map(\.number) == Array(1...9) else {
            throw CourseManifestError.invalidHoleSequence
        }
        for hole in document.holes {
            guard (3...5).contains(hole.par), (1...1_000).contains(hole.distanceYards),
                  [hole.id, hole.name, hole.summary, hole.landmark].allSatisfy(Self.hasText) else {
                throw CourseManifestError.invalidHole(number: hole.number)
            }
        }
        return CourseManifest(
            id: document.id, name: document.name, summary: document.summary,
            contentVersion: document.contentVersion, holes: document.holes
        )
    }

    private static func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private struct Document: Decodable {
        let schemaVersion: Int
        let contentVersion: Int
        let id: String
        let name: String
        let summary: String
        let holes: [HoleSummary]
    }
}

public enum CourseManifestError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedSchema(Int)
    case invalidMetadata
    case invalidHoleCount
    case duplicateHoleID
    case invalidHoleSequence
    case invalidHole(number: Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "This course needs a different version of OffsideGolf."
        case .invalidMetadata: "The course information could not be read."
        case .invalidHoleCount: "The course must contain nine holes."
        case .duplicateHoleID: "Two holes have the same identity."
        case .invalidHoleSequence: "The course holes are not in the expected order."
        case .invalidHole(let number): "The information for hole \(number) is invalid."
        }
    }
}
