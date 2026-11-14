import AudioToolbox
import Foundation

enum AudioCueLevel: Int, CaseIterable {
    case muted = 0
    case regular = 1
    case everyMinute = 2
    case every30Seconds = 3
    case everySecond = 4

    var label: String {
        switch self {
        case .muted: return "Mute"
        case .regular: return "Regular"
        case .everyMinute: return "Level 2 — double beep every minute"
        case .every30Seconds: return "Level 3 — + single beep every 30 sec"
        case .everySecond: return "Level 4 — + tick every second"
        }
    }

    var shortTitle: String {
        switch self {
        case .muted: return "Mute"
        case .regular: return "Regular"
        case .everyMinute: return "Level 2"
        case .every30Seconds: return "Level 3"
        case .everySecond: return "Level 4"
        }
    }

    /// The minute-mark intervals offered in the Audio Cues sheet.
    static let minuteMarkIntervals = [1, 2, 3]

    static func minuteRemainingText(_ minutes: Int) -> String {
        "\(minutes) minute\(minutes == 1 ? "" : "s")" + remainingSuffix
    }

    static func secondsRemainingText(_ seconds: Int) -> String {
        "\(seconds) seconds" + remainingSuffix
    }

    /// Read at speak time so a change in the Audio Cues sheet applies to the
    /// next announcement. Defaults to on when the key has never been set.
    private static var remainingSuffix: String {
        let sayRemaining = (UserDefaults.standard.object(forKey: Keys.sayRemaining) as? Bool) ?? true
        return sayRemaining ? " remaining" : ""
    }

    /// Plays this level's beep for a given remaining-seconds mark, if any.
    /// Only the single most-prominent cue plays at a shared instant (e.g. a
    /// 60s mark is also a 30s mark, but only the minute cue sounds there).
    /// Callers must suppress this entirely on ticks where a spoken
    /// announcement already fired — speech always takes priority over beeps.
    /// When `speakMinuteMarks` is on, the minute-mark cue (Levels 2–4) speaks
    /// the remaining minutes via `speak` instead of playing the double beep.
    /// Minute marks fall every `minuteInterval` minutes of time remaining; at
    /// Levels 3–4 a skipped minute still gets the 30-second single beep.
    func playCue(remaining: Int, minuteInterval: Int, speakMinuteMarks: Bool, speak: (Int) -> Void) {
        guard remaining > 0 else { return }
        switch self {
        case .muted, .regular:
            return
        case .everyMinute:
            cueMinuteMark(remaining: remaining, minuteInterval: minuteInterval, speakMinuteMarks: speakMinuteMarks, speak: speak)
        case .every30Seconds:
            if !cueMinuteMark(remaining: remaining, minuteInterval: minuteInterval, speakMinuteMarks: speakMinuteMarks, speak: speak) {
                if remaining % 30 == 0 { AudioCueTone.single.play() }
            }
        case .everySecond:
            if !cueMinuteMark(remaining: remaining, minuteInterval: minuteInterval, speakMinuteMarks: speakMinuteMarks, speak: speak) {
                if remaining % 30 == 0 {
                    AudioCueTone.single.play()
                } else {
                    AudioCueTone.tick.play()
                }
            }
        } 
    }

    @discardableResult
    private func cueMinuteMark(remaining: Int, minuteInterval: Int, speakMinuteMarks: Bool, speak: (Int) -> Void) -> Bool {
        guard remaining % (60 * max(1, minuteInterval)) == 0 else { return false }
        if speakMinuteMarks {
            speak(remaining / 60)
        } else {
            AudioCueTone.double.play()
        }
        return true
    }
}

enum AudioCueTone {
    case double, single, tick

    func play() {
        let repeats = self == .double ? 2 : 1
        Self.playSystemSound(id: soundID, repeats: repeats)
    }

    /// Falls back to a per-tone default when the user hasn't set a custom ID
    /// in Settings yet. UserDefaults returns 0 for an absent Int key, which
    /// is never a valid sound ID, so 0 doubles as the "unset" sentinel here.
    private var soundID: SystemSoundID {
        let key: String
        let defaultID: Int
        switch self {
        case .double: key = Keys.doubleBeepSoundID; defaultID = 1210
        case .single: key = Keys.singleBeepSoundID; defaultID = 1104
        case .tick: key = Keys.tickSoundID; defaultID = 1157
        }
        let stored = UserDefaults.standard.integer(forKey: key)
        return SystemSoundID(stored != 0 ? stored : defaultID)
    }

    private static func playSystemSound(id: SystemSoundID, repeats: Int) {
        for i in 0..<repeats {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AudioServicesPlaySystemSound(id)
            }
        }
    }
}
