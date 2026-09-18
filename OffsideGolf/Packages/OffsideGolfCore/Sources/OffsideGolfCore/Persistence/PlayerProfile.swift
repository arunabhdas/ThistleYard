import Foundation

public struct GameSettings: Codable, Equatable, Sendable {
    public var musicVolume: Double = 0.65
    public var ambientVolume: Double = 0.8
    public var effectsVolume: Double = 0.85
    public var interfaceVolume: Double = 0.7
    public var hapticsEnabled = true
    public var reducedMotion = false
    public var highContrast = false
    public var leftHanded = false
    public var preciseControls = false
    public var slopeGuide = true
    public init() {}
}

/// Palette indices are stable content identifiers, independent of platform colors.
public struct GolferAppearance: Codable, Equatable, Sendable {
    public var skinPalette: Int
    public var hairStyle: Int
    public var outfitPalette: Int
    public init(skinPalette: Int = 0, hairStyle: Int = 0, outfitPalette: Int = 0) {
        self.skinPalette = skinPalette; self.hairStyle = hairStyle; self.outfitPalette = outfitPalette
    }
}

public struct CourseRecord: Codable, Equatable, Sendable {
    public var courseID: String
    public var contentVersion: Int
    public var physicsVersion: Int
    public var bestTotalStrokes: Int?
    public var holeBestStrokes: [String: Int]
    public init(courseID: String, bestTotalStrokes: Int? = nil, holeBestStrokes: [String: Int] = [:],
                contentVersion: Int = 1, physicsVersion: Int = 1) {
        self.courseID = courseID; self.bestTotalStrokes = bestTotalStrokes; self.holeBestStrokes = holeBestStrokes
        self.contentVersion = contentVersion; self.physicsVersion = physicsVersion
    }
    public func matches(courseID: String, contentVersion: Int, physicsVersion: Int) -> Bool {
        self.courseID == courseID && self.contentVersion == contentVersion && self.physicsVersion == physicsVersion
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        courseID = try values.decode(String.self, forKey: .courseID)
        bestTotalStrokes = try values.decodeIfPresent(Int.self, forKey: .bestTotalStrokes)
        holeBestStrokes = try values.decode([String: Int].self, forKey: .holeBestStrokes)
        // Schema-1 saves written before record versioning belong to the original tuning.
        contentVersion = try values.decodeIfPresent(Int.self, forKey: .contentVersion) ?? 1
        physicsVersion = try values.decodeIfPresent(Int.self, forKey: .physicsVersion) ?? 1
    }
}

public struct PlayerProfile: Codable, Equatable, Sendable {
    public var id: UUID
    public var settings: GameSettings
    public var appearance: GolferAppearance
    public var tutorialCompleted: Bool
    public var records: [CourseRecord]
    public init(id: UUID = UUID(), settings: GameSettings = GameSettings(),
                appearance: GolferAppearance = GolferAppearance(), tutorialCompleted: Bool = false,
                records: [CourseRecord] = []) {
        self.id = id; self.settings = settings; self.appearance = appearance
        self.tutorialCompleted = tutorialCompleted; self.records = records
    }
}
