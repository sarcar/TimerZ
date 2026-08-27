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

    init() {
        let verbalCountdownEnabled = (UserDefaults.standard.object(forKey: Keys.verbalCountdownEnabled) as? Bool) ?? true
        audioCueLevel = verbalCountdownEnabled ? .regular : .muted
    }
}
