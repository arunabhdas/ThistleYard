import Foundation

/// Persisted, independent category levels. Hardware never receives a nonfinite volume.
struct AudioSettings: Codable, Equatable, Sendable {
    var musicVolume: Float { didSet { musicVolume = Self.clamp(musicVolume) } }
    var ambientVolume: Float { didSet { ambientVolume = Self.clamp(ambientVolume) } }
    var sfxVolume: Float { didSet { sfxVolume = Self.clamp(sfxVolume) } }
    var uiVolume: Float { didSet { uiVolume = Self.clamp(uiVolume) } }
    var isMuted: Bool
    var hapticsEnabled: Bool

    init(musicVolume: Float = 0.35, ambientVolume: Float = 0.45, sfxVolume: Float = 0.7,
         uiVolume: Float = 0.4, isMuted: Bool = false, hapticsEnabled: Bool = true) {
        self.musicVolume = Self.clamp(musicVolume)
        self.ambientVolume = Self.clamp(ambientVolume)
        self.sfxVolume = Self.clamp(sfxVolume)
        self.uiVolume = Self.clamp(uiVolume)
        self.isMuted = isMuted
        self.hapticsEnabled = hapticsEnabled
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(musicVolume: try values.decodeIfPresent(Float.self, forKey: .musicVolume) ?? 0.35,
                  ambientVolume: try values.decodeIfPresent(Float.self, forKey: .ambientVolume) ?? 0.45,
                  sfxVolume: try values.decodeIfPresent(Float.self, forKey: .sfxVolume) ?? 0.7,
                  uiVolume: try values.decodeIfPresent(Float.self, forKey: .uiVolume) ?? 0.4,
                  isMuted: try values.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false,
                  hapticsEnabled: try values.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true)
    }

    static func clamp(_ value: Float) -> Float { value.isFinite ? min(1, max(0, value)) : 0 }
}
