import AppKit

@MainActor
final class DictationSoundPlayer {
    static let shared = DictationSoundPlayer()

    private let startSound = NSSound(contentsOfFile: "/System/Library/Sounds/Tink.aiff", byReference: true)
    private let endSound = NSSound(contentsOfFile: "/System/Library/Sounds/Pop.aiff", byReference: true)

    private init() {
        startSound?.volume = 0.45
        endSound?.volume = 0.45
    }

    func playStart() {
        play(startSound)
    }

    func playEnd() {
        play(endSound)
    }

    private func play(_ sound: NSSound?) {
        guard let sound else {
            return
        }
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }
}
