import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum GolfAudioEffect: String, CaseIterable, Sendable {
    case swing, impact, bounce, roll, sand, splash, cup, ui

    var resource: String { self == .ui ? "ui_tap" : "golf_\(rawValue)" }
}

@MainActor
protocol AudioPlayer: AnyObject {
    var volume: Float { get set }
    var isPlaying: Bool { get }
    func play(looping: Bool)
    func pause()
    func stop()
}

/// The only hardware boundary; policy, event deduplication and category levels remain in AudioManager.
@MainActor
protocol AudioOutput: AnyObject {
    func activate()
    func deactivate()
    func makePlayer(resource: String) -> (any AudioPlayer)?
}

@MainActor
final class AudioManager {
    private(set) var settings: AudioSettings
    private let output: any AudioOutput
    private var effects: [(player: any AudioPlayer, effect: GolfAudioEffect, intensity: Float)] = []
    private var ambience: [any AudioPlayer] = []
    private var music: (any AudioPlayer)?
    private var wantsAmbience = false
    private var wantsMusic = false
    private var suspended = false
    private var interrupted = false
    private var interruptionAllowsResume = true
    private var recentEvents: Set<String> = []
    private var eventOrder: [String] = []
    private let observations = AudioObservationTokens()

    init(settings: AudioSettings = AudioSettings(), output: (any AudioOutput)? = nil) {
        self.settings = settings
        self.output = output ?? BundledAudioOutput()
        observeLifecycle()
    }

    func updateSettings(_ settings: AudioSettings) {
        self.settings = settings
        for voice in effects {
            voice.player.volume = level(for: voice.effect) * voice.intensity
        }
        reconcileLoops()
    }

    /// Give repeated deliveries of the same semantic event the same ID.
    /// For multiple bounces in a shot, include the bounce index in the ID.
    func play(_ effect: GolfAudioEffect, eventID: String? = nil, intensity: Float = 1) {
        if let eventID {
            let key = "\(effect.rawValue):\(eventID)"
            guard recentEvents.insert(key).inserted else { return }
            eventOrder.append(key)
            if eventOrder.count > 256 { recentEvents.remove(eventOrder.removeFirst()) }
        }
        let intensity = AudioSettings.clamp(intensity)
        guard canPlay, level(for: effect) > 0, intensity > 0 else { return }
        effects.removeAll { !$0.player.isPlaying }
        if effects.count >= 12 { effects.removeFirst().player.stop() }
        output.activate()
        guard let player = output.makePlayer(resource: effect.resource) else { return }
        player.volume = level(for: effect) * intensity
        player.play(looping: false)
        effects.append((player, effect, intensity))
    }

    func startAmbience() {
        wantsAmbience = true
        interruptionAllowsResume = true
        reconcileLoops()
    }

    func stopAmbience() {
        wantsAmbience = false
        ambience.forEach { $0.stop() }
        ambience.removeAll()
    }

    /// The authored loop contains long silent rests between sparse musical phrases.
    func startMusic() {
        wantsMusic = true
        interruptionAllowsResume = true
        reconcileLoops()
    }

    func stopMusic() {
        wantsMusic = false
        music?.stop()
        music = nil
    }

    func suspend() {
        suspended = true
        reconcileLoops()
    }

    func resume() {
        suspended = false
        reconcileLoops()
    }

    func handleInterruption(began: Bool, shouldResume: Bool = false) {
        interrupted = began
        if !began { interruptionAllowsResume = shouldResume }
        reconcileLoops()
    }

    func shutdown() {
        stopAmbience()
        stopMusic()
        effects.forEach { $0.player.stop() }
        effects.removeAll()
        output.deactivate()
    }

    private var canPlay: Bool {
        !settings.isMuted && !suspended && !interrupted && interruptionAllowsResume
    }

    private func level(for effect: GolfAudioEffect) -> Float {
        effect == .ui ? settings.uiVolume : settings.sfxVolume
    }

    private func reconcileLoops() {
        guard canPlay else {
            ambience.forEach { $0.pause() }
            music?.pause()
            effects.forEach { $0.player.stop() }
            effects.removeAll()
            output.deactivate()
            return
        }
        if wantsAmbience || wantsMusic { output.activate() }
        if wantsAmbience {
            if ambience.isEmpty {
                ambience = ["coast_birds", "coast_wind", "coast_waves"].compactMap { output.makePlayer(resource: $0) }
            }
            for player in ambience {
                player.volume = settings.ambientVolume
                if settings.ambientVolume == 0 { player.pause() }
                else if !player.isPlaying { player.play(looping: true) }
            }
        }
        if wantsMusic {
            if music == nil { music = output.makePlayer(resource: "coast_music") }
            music?.volume = settings.musicVolume
            if settings.musicVolume == 0 { music?.pause() }
            else if music?.isPlaying == false { music?.play(looping: true) }
        }
    }

    private func observeLifecycle() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        observations.tokens.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.suspend() }
        })
        observations.tokens.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
        })
        observations.tokens.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self, let type, let kind = AVAudioSession.InterruptionType(rawValue: type) else { return }
                self.handleInterruption(began: kind == .began,
                                        shouldResume: AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume))
            }
        })
        #endif
    }
}

/// Tokens are only mutated on the main actor; their destruction can occur on any thread.
private final class AudioObservationTokens: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []
    deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
}

@MainActor
private final class BundledAudioOutput: AudioOutput {
    private var active = false

    func activate() {
        guard !active else { return }
        #if canImport(UIKit)
        do {
            // Ambient respects the physical silent switch, mixes with other audio and stops when locked.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            active = true
        } catch { active = false }
        #else
        active = true
        #endif
    }

    func deactivate() {
        guard active else { return }
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        active = false
    }

    func makePlayer(resource: String) -> (any AudioPlayer)? {
        let url = ["m4a", "wav"].lazy.compactMap { ext in
            Bundle.main.url(forResource: resource, withExtension: ext)
                ?? Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: "Audio")
        }.first
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return BundledAudioPlayer(player: player)
    }
}

@MainActor
private final class BundledAudioPlayer: AudioPlayer {
    private let player: AVAudioPlayer
    init(player: AVAudioPlayer) { self.player = player }
    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }
    var isPlaying: Bool { player.isPlaying }
    func play(looping: Bool) {
        player.numberOfLoops = looping ? -1 : 0
        player.play()
    }
    func pause() { player.pause() }
    func stop() { player.stop(); player.currentTime = 0 }
}
