import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private enum Track {
        case startScreen
        case gameplay
    }

    private var startPlayer: AVAudioPlayer?
    private var gameplayPlayer: AVAudioPlayer?
    private var activeTrack: Track?
    private var sessionConfigured = false
    private var masterVolume: Float = 0.6

    private init() {
        preparePlayers()
    }

    func preparePlayers() {
        configureSessionIfNeeded()
        if startPlayer == nil {
            startPlayer = makePlayer(named: "StartScreen")
        }
        if gameplayPlayer == nil {
            gameplayPlayer = makePlayer(named: "Gameplay")
        }
    }

    func playStartScreenLoop() {
        switchTo(track: .startScreen)
    }

    func playGameplayLoop() {
        switchTo(track: .gameplay)
    }

    func stopStartScreenLoop() {
        guard activeTrack == .startScreen else { return }
        stopCurrent()
    }

    func stopGameplayLoop() {
        guard activeTrack == .gameplay else { return }
        stopCurrent()
    }

    func stopAll() {
        stopCurrent()
    }

    func setVolume(_ volume: Double) {
        let clamped = Float(min(max(volume, 0), 1))
        masterVolume = clamped
        startPlayer?.volume = clamped
        gameplayPlayer?.volume = clamped
    }

    // MARK: - Private

    private func switchTo(track: Track) {
        if activeTrack == track {
            restartIfPaused(for: track)
            return
        }

        stopCurrent()
        guard let player = player(for: track) else { return }

        player.currentTime = 0
        player.play()
        activeTrack = track
    }

    private func restartIfPaused(for track: Track) {
        guard let player = player(for: track) else { return }
        if !player.isPlaying {
            player.currentTime = 0
            player.play()
        }
    }

    private func player(for track: Track) -> AVAudioPlayer? {
        switch track {
        case .startScreen:
            return startPlayer
        case .gameplay:
            return gameplayPlayer
        }
    }

    private func stopCurrent() {
        switch activeTrack {
        case .startScreen:
            startPlayer?.stop()
            startPlayer?.currentTime = 0
        case .gameplay:
            gameplayPlayer?.stop()
            gameplayPlayer?.currentTime = 0
        case .none:
            break
        }
        activeTrack = nil
    }

    private func makePlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("AudioManager: Missing \(name).mp3 in bundle")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = masterVolume
            player.prepareToPlay()
            return player
        } catch {
            print("AudioManager: Failed to load \(name).mp3: \(error)")
            return nil
        }
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioManager: Failed to configure AVAudioSession: \(error)")
        }
    }
}
