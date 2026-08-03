import AVFoundation

/// Keeps a near-silent audio loop playing so iOS treats the app as
/// legitimately using its "audio" background mode, which keeps the app's
/// process (and its per-second Timer ticks) running while the phone is
/// locked or the app is backgrounded — required for verbal countdown
/// announcements to have any chance of firing outside the foreground.
final class BackgroundAudioKeepAlive {
    private var player: AVAudioPlayer?

    func start() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "Silence", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0.01
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {}
    }

    func stop() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
