import Foundation
import Observation

@Observable
final class AppState {
    #if targetEnvironment(simulator)
    var testModeEnabled = true
    #else
    var testModeEnabled = false
    #endif

    var audioCueLevel: AudioCueLevel
    var lastNonMutedAudioCueLevel: AudioCueLevel = .regular
    var speakMinuteMarks = false

    /// Tracks an in-progress run of consecutive long-press-continued timers.
    /// Ephemeral (in-memory only) — resets to a fresh chain on app relaunch.
    var currentChainCount = 1
    var currentChainElapsedSeconds = 0

    init() {
        let verbalCountdownEnabled = (UserDefaults.standard.object(forKey: Keys.verbalCountdownEnabled) as? Bool) ?? true
        audioCueLevel = verbalCountdownEnabled ? .regular : .muted
    }
}
