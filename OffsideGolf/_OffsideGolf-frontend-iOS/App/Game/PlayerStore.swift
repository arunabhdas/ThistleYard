import Foundation
import Observation
import OffsideGolfCore
import UIKit

/// Serializes save requests in gameplay order, in addition to the repository's atomic I/O.
@MainActor @Observable
final class PlayerStore {
    private(set) var save = SaveGame()
    private(set) var loaded = false
    private(set) var saving = false
    private(set) var errorMessage: String?
    private(set) var recovery: SaveGame?
    private(set) var storageBlocked = false
    @ObservationIgnored private let repository: FileGameRepository
    @ObservationIgnored private var pendingWrite: Task<Void, Never>?
    @ObservationIgnored private var writeNumber = 0
    @ObservationIgnored private var recoveryWriteRequired = false
    @ObservationIgnored private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    @ObservationIgnored let audio = AudioManager()

    init(repository: FileGameRepository = FileGameRepository()) { self.repository = repository }
    var settings: GameSettings { save.profile.settings }
    var appearance: GolferAppearance { save.profile.appearance }

    func load() async {
        guard !loaded else { return }
        switch await repository.load() {
        case .current(let value): save = value
        case .absent: break
        case .recoveredBackup(let value, _):
            recovery = value; storageBlocked = true
            errorMessage = "Your last save could not be opened. A previous checkpoint is available."
        case .failure(let current, _):
            storageBlocked = true; errorMessage = current.localizedDescription
        }
        loaded = true; applyAudioSettings()
    }
    func retryLoad() async {
        loaded = false; storageBlocked = false; errorMessage = nil; recovery = nil
        await load()
    }
    func recoverBackup() {
        guard let recovery else { return }
        save = recovery; self.recovery = nil; storageBlocked = false; recoveryWriteRequired = true
        enqueueWrite(replacingCorrupt: true)
        applyAudioSettings()
    }
    func updateSettings(_ settings: GameSettings) {
        save.profile.settings = settings; applyAudioSettings(); enqueueWrite()
    }
    func updateAppearance(_ appearance: GolferAppearance) {
        save.profile.appearance = appearance; enqueueWrite()
    }
    func finishTutorial() { save.profile.tutorialCompleted = true; enqueueWrite() }
    func setRound(_ round: RoundProgress?) { save.round = round; enqueueWrite() }
    func retrySave() { enqueueWrite() }
    func recordPractice(_ score: SavedHoleScore, courseID: String, contentVersion: Int, physicsVersion: Int, eligible: Bool) {
        guard eligible else { return }
        var record = matchingRecord(courseID: courseID,contentVersion: contentVersion,physicsVersion: physicsVersion)
        record.holeBestStrokes[score.holeID] = min(record.holeBestStrokes[score.holeID] ?? score.strokes,score.strokes)
        replaceRecord(record)
        enqueueWrite()
    }
    func finishRound(_ scores: [SavedHoleScore], courseID: String, contentVersion: Int, physicsVersion: Int, eligible: Bool) {
        if eligible {
            let total = scores.reduce(0) { $0 + $1.strokes }
            var record = matchingRecord(courseID: courseID,contentVersion: contentVersion,physicsVersion: physicsVersion)
            record.bestTotalStrokes = min(record.bestTotalStrokes ?? total,total)
            for score in scores { record.holeBestStrokes[score.holeID] = min(record.holeBestStrokes[score.holeID] ?? score.strokes,score.strokes) }
            replaceRecord(record)
        }
        save.round = nil; enqueueWrite()
    }
    private func matchingRecord(courseID: String,contentVersion: Int,physicsVersion: Int) -> CourseRecord {
        save.profile.records.first { $0.matches(courseID: courseID,contentVersion: contentVersion,physicsVersion: physicsVersion) }
            ?? CourseRecord(courseID: courseID,contentVersion: contentVersion,physicsVersion: physicsVersion)
    }
    private func replaceRecord(_ record: CourseRecord) {
        save.profile.records.removeAll { $0.matches(courseID: record.courseID,contentVersion: record.contentVersion,physicsVersion: record.physicsVersion) }
        save.profile.records.append(record)
    }
    func flush() async { await pendingWrite?.value }
    func flushForBackground() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save golf progress") { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
        Task { [weak self] in
            await self?.flush()
            self?.endBackgroundTask()
        }
    }
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    private func enqueueWrite(replacingCorrupt: Bool = false) {
        guard loaded, !storageBlocked else { return }
        let snapshot = save
        let replacingCorrupt = replacingCorrupt || recoveryWriteRequired
        let earlier = pendingWrite
        writeNumber += 1
        let number = writeNumber
        saving = true
        pendingWrite = Task { [weak self, repository] in
            await earlier?.value
            do {
                let persisted = try await repository.save(snapshot,replacingCorruptCurrent: replacingCorrupt)
                guard let self else { return }
                self.save.revision = persisted.revision
                self.recoveryWriteRequired = false
                if number == self.writeNumber { self.saving = false; self.errorMessage = nil }
            } catch {
                guard let self else { return }
                if number == self.writeNumber { self.saving = false; self.errorMessage = error.localizedDescription }
            }
        }
    }
    private func applyAudioSettings() {
        audio.updateSettings(AudioSettings(musicVolume: Float(settings.musicVolume),ambientVolume: Float(settings.ambientVolume),
                                          sfxVolume: Float(settings.effectsVolume),uiVolume: Float(settings.interfaceVolume),
                                          hapticsEnabled: settings.hapticsEnabled))
    }
}
