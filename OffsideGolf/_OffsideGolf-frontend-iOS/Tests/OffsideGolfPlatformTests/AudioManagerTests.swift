import XCTest
@testable import OffsideGolf

@MainActor
final class AudioManagerTests: XCTestCase {
    func testVolumesClampAndInvalidDecodedVolumesCannotReachAudioHardware() throws {
        var settings = AudioSettings(musicVolume: -1, ambientVolume: 2, sfxVolume: .nan, uiVolume: .infinity)
        XCTAssertEqual(settings.musicVolume, 0)
        XCTAssertEqual(settings.ambientVolume, 1)
        XCTAssertEqual(settings.sfxVolume, 0)
        XCTAssertEqual(settings.uiVolume, 0)
        settings.musicVolume = 4
        settings.ambientVolume = -3
        XCTAssertEqual(settings.musicVolume, 1)
        XCTAssertEqual(settings.ambientVolume, 0)
        let decoded = try JSONDecoder().decode(AudioSettings.self, from: Data("{\"musicVolume\":-4,\"ambientVolume\":8,\"sfxVolume\":0.3,\"uiVolume\":0.7,\"isMuted\":false,\"hapticsEnabled\":true}".utf8))
        XCTAssertEqual(decoded.musicVolume, 0)
        XCTAssertEqual(decoded.ambientVolume, 1)
    }

    func testIndependentCategoryLevelsReachPlayersAndUpdateLive() {
        let output = RecordingAudioOutput()
        let manager = AudioManager(settings: AudioSettings(musicVolume: 0.1, ambientVolume: 0.2, sfxVolume: 0.3, uiVolume: 0.4), output: output)
        manager.startAmbience()
        manager.startMusic()
        manager.play(.impact)
        manager.play(.ui)
        XCTAssertEqual(output.players["coast_music"]?.volume, 0.1)
        XCTAssertEqual(output.players["coast_wind"]?.volume, 0.2)
        XCTAssertEqual(output.players["golf_impact"]?.volume, 0.3)
        XCTAssertEqual(output.players["ui_tap"]?.volume, 0.4)
        var settings = manager.settings
        settings.sfxVolume = 0.8
        settings.musicVolume = 0.6
        manager.updateSettings(settings)
        XCTAssertEqual(output.players["golf_impact"]?.volume, 0.8)
        XCTAssertEqual(output.players["coast_music"]?.volume, 0.6)
        XCTAssertEqual(output.players["ui_tap"]?.volume, 0.4)
    }

    func testDuplicateEventIsSuppressedButDifferentEffectsAndShotsPlay() {
        let output = RecordingAudioOutput()
        let manager = AudioManager(output: output)
        manager.play(.impact, eventID: "shot-1")
        manager.play(.impact, eventID: "shot-1")
        manager.play(.splash, eventID: "shot-1")
        manager.play(.impact, eventID: "shot-2")
        XCTAssertEqual(output.createdNames, ["golf_impact", "golf_splash", "golf_impact"])
    }

    func testMutedAndSuspendedEffectsDoNotPlayAndRequestedLoopsResume() {
        let output = RecordingAudioOutput()
        let manager = AudioManager(output: output)
        manager.startAmbience()
        manager.startMusic()
        manager.suspend()
        XCTAssertTrue(output.players.values.allSatisfy { !$0.isPlaying })
        let count = output.createdNames.count
        manager.play(.impact)
        XCTAssertEqual(output.createdNames.count, count)
        manager.resume()
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, true)
        var settings = manager.settings
        settings.isMuted = true
        manager.updateSettings(settings)
        manager.play(.ui)
        XCTAssertTrue(output.players.values.allSatisfy { !$0.isPlaying })
        settings.isMuted = false
        manager.updateSettings(settings)
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, true)
        manager.stopMusic()
        manager.suspend()
        manager.resume()
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, false)
        manager.shutdown()
    }

    func testInterruptionRespectsResumePermissionAndBackgroundState() {
        let output = RecordingAudioOutput()
        let manager = AudioManager(output: output)
        manager.startMusic()
        manager.handleInterruption(began: true)
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, false)
        manager.handleInterruption(began: false, shouldResume: false)
        manager.resume()
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, false)
        manager.startMusic() // A fresh user request can play again.
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, true)
        manager.handleInterruption(began: true)
        manager.suspend()
        manager.handleInterruption(began: false, shouldResume: true)
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, false)
        manager.resume()
        XCTAssertEqual(output.players["coast_music"]?.isPlaying, true)
    }

    func testHapticOptOutSuppressesFeedbackAndEnablingRestoresSubtleFeedback() {
        let output = RecordingHapticOutput()
        let manager = HapticManager(isEnabled: false, output: output)
        manager.play(.impact)
        manager.play(.cup)
        manager.play(.selection)
        XCTAssertTrue(output.impacts.isEmpty)
        XCTAssertEqual(output.selections, 0)
        manager.isEnabled = true
        manager.play(.impact)
        manager.play(.cup)
        manager.play(.selection)
        XCTAssertEqual(output.impacts, [0.35, 0.6])
        XCTAssertEqual(output.selections, 1)
    }

    func testImpactIntensityRemainsScaledWhenSettingsChange() {
        let output = RecordingAudioOutput()
        let manager = AudioManager(settings: AudioSettings(sfxVolume: 0.8), output: output)
        manager.play(.bounce, intensity: 0.25)
        XCTAssertEqual(output.players["golf_bounce"]?.volume ?? -1, 0.2, accuracy: 0.001)
        var settings = manager.settings
        settings.sfxVolume = 0.4
        manager.updateSettings(settings)
        XCTAssertEqual(output.players["golf_bounce"]?.volume ?? -1, 0.1, accuracy: 0.001)
    }
}

@MainActor
private final class RecordingAudioOutput: AudioOutput {
    var players: [String: RecordingAudioPlayer] = [:]
    var createdNames: [String] = []
    func activate() {}
    func deactivate() {}
    func makePlayer(resource: String) -> (any AudioPlayer)? {
        let player = RecordingAudioPlayer()
        players[resource] = player
        createdNames.append(resource)
        return player
    }
}

@MainActor
private final class RecordingAudioPlayer: AudioPlayer {
    var volume: Float = 1
    var isPlaying = false
    func play(looping: Bool) { isPlaying = true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false }
}

@MainActor
private final class RecordingHapticOutput: HapticOutput {
    var impacts: [Double] = []
    var selections = 0
    func impact(intensity: Double) { impacts.append(intensity) }
    func selection() { selections += 1 }
}
