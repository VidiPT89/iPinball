import AVFoundation

/// The voices the table can speak with.
enum SoundVoice: CaseIterable {
    case flipper, plunger, plungerNotch, nudge
    case bumper, slingshot, target, dropTarget, bankClear, spinner
    case ramp, orbit, lane, laneSet
    case jackpot, superJackpot, mission, missionFail, multiball
    case tilt, drain, extraBall, gameOver, uiTap
}

/// A tiny synthesiser. Every sound is generated into a PCM buffer at launch,
/// so the app carries no audio files and the whole soundtrack is a few
/// hundred kilobytes of arithmetic.
final class AudioEngine {

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0

    private let musicPlayer = AVAudioPlayerNode()
    private var musicBuffer: AVAudioPCMBuffer?

    private var buffers: [SoundVoice: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    var isSoundEnabled = true
    var isMusicEnabled = true

    private var isRunning = false
    /// Stops a burst of identical contacts turning into a buzz.
    private var lastPlayed: [SoundVoice: TimeInterval] = [:]
    private var lastPlungerNotch = -1

    // MARK: - Lifecycle

    init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        for _ in 0..<12 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: format)
            voices.append(node)
        }

        engine.attach(musicPlayer)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)
        musicPlayer.volume = 0.16

        for voice in SoundVoice.allCases {
            buffers[voice] = render(Recipe.for(voice))
        }
        musicBuffer = renderMusicLoop()
    }

    func start() {
        guard !isRunning else { return }
        configureSession()
        do {
            try engine.start()
            isRunning = true
            voices.forEach { $0.play() }
            if isMusicEnabled { startMusic() }
        } catch {
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        musicPlayer.stop()
        voices.forEach { $0.stop() }
        engine.pause()
        isRunning = false
    }

    private func configureSession() {
        #if os(iOS)
        // Ambient, so the game never silences the player's own music.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    // MARK: - Music

    func setMusic(enabled: Bool) {
        isMusicEnabled = enabled
        guard isRunning else { return }
        enabled ? startMusic() : musicPlayer.stop()
    }

    private func startMusic() {
        guard let musicBuffer, !musicPlayer.isPlaying else { return }
        musicPlayer.scheduleBuffer(musicBuffer, at: nil, options: [.loops])
        musicPlayer.play()
    }

    // MARK: - Playback

    func play(_ voice: SoundVoice) {
        guard isSoundEnabled, isRunning, let buffer = buffers[voice] else { return }

        let now = CACurrentMediaTime()
        if let last = lastPlayed[voice], now - last < Recipe.for(voice).minimumGap { return }
        lastPlayed[voice] = now

        let node = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        node.volume = Recipe.for(voice).gain
        node.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        if !node.isPlaying { node.play() }
    }

    /// The plunger ratchets as it is pulled back: one click per notch, the
    /// way a real spring-loaded shooter sounds.
    func plungerCharge(_ fraction: CGFloat) {
        guard isSoundEnabled, isRunning else { return }
        let notch = Int(max(0, min(1, fraction)) / 0.12)
        guard notch != lastPlungerNotch else { return }
        lastPlungerNotch = notch
        play(.plungerNotch)
    }

    /// Reset when the ball is served so the next pull clicks from the start.
    func resetPlunger() {
        lastPlungerNotch = -1
    }

    func play(for effect: GameEffect) {
        switch effect {
        case .scored(_, let label):    play(voice(for: label))
        case .laneLit:                 play(.lane)
        case .laneSetCompleted:        play(.laneSet)
        case .dropTargetDown:          play(.dropTarget)
        case .dropBankReset:           play(.bankClear)
        case .missionStarted:          play(.mission)
        case .missionCompleted:        play(.mission)
        case .missionFailed:           play(.missionFail)
        case .multiballStarted:        play(.multiball)
        case .jackpotLit:              play(.lane)
        case .jackpotCollected:        play(.jackpot)
        case .superJackpotCollected:   play(.superJackpot)
        case .wizardModeStarted:       play(.multiball)
        case .extraBallAwarded:        play(.extraBall)
        case .ballSaved:               play(.extraBall)
        case .ballLost:                play(.drain)
        case .tilted, .tiltWarning:    play(.tilt)
        case .gameOver:                play(.gameOver)
        case .comboChanged, .playerMultiplierChanged, .multiballEnded,
             .ballSaveArmed, .bonusAwarded, .missionProgressed:
            break
        }
    }

    private func voice(for label: ScoreLabel) -> SoundVoice {
        switch label {
        case .bumper:        return .bumper
        case .slingshot:     return .slingshot
        case .target:        return .target
        case .dropTarget:    return .dropTarget
        case .bankClear:     return .bankClear
        case .spinner:       return .spinner
        case .ramp:          return .ramp
        case .orbit:         return .orbit
        case .lane:          return .lane
        case .laneSet:       return .laneSet
        case .jackpot:       return .jackpot
        case .superJackpot:  return .superJackpot
        case .mission:       return .mission
        case .bonus:         return .extraBall
        case .combo:         return .orbit
        }
    }

    // MARK: - Synthesis

    private func render(_ recipe: Recipe) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(recipe.duration * format.sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames

        var phase = 0.0
        let sampleRate = format.sampleRate

        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            let progress = t / recipe.duration

            let frequency = recipe.startFrequency
                + (recipe.endFrequency - recipe.startFrequency) * progress
            phase += 2 * .pi * frequency / sampleRate

            var value = recipe.waveform.sample(phase: phase)
            if recipe.noise > 0 {
                value += Double.random(in: -1...1) * recipe.noise
            }
            value *= exp(-recipe.decay * t)
            // Short fade in and out, otherwise every hit starts with a click.
            value *= edgeFade(progress: progress)

            samples[frame] = Float(max(-1, min(1, value)) * 0.7)
        }
        return buffer
    }

    private func edgeFade(progress: Double) -> Double {
        let edge = 0.02
        if progress < edge { return progress / edge }
        if progress > 1 - edge { return (1 - progress) / edge }
        return 1
    }

    /// Four bars of a slow minor arpeggio, quiet enough to sit under the table.
    private func renderMusicLoop() -> AVAudioPCMBuffer? {
        let duration = 8.0
        let frames = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames

        // A minor: A2 C3 E3 G3, walking up and back down.
        let notes = [110.0, 130.81, 164.81, 196.00, 164.81, 130.81]
        let noteLength = duration / Double(notes.count)
        let sampleRate = format.sampleRate

        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            let index = min(notes.count - 1, Int(t / noteLength))
            let local = t - Double(index) * noteLength
            let note = notes[index]

            let envelope = exp(-1.6 * local) * (local < 0.01 ? local / 0.01 : 1)
            var value = sin(2 * .pi * note * t) * 0.6
            value += sin(2 * .pi * note * 2 * t) * 0.2   // octave shimmer
            value += sin(2 * .pi * 55 * t) * 0.25        // low pad underneath
            samples[frame] = Float(value * envelope * 0.5)
        }
        return buffer
    }

    // MARK: - Recipes

    /// One line per sound. Tuning the table's voice means editing this table.
    struct Recipe {
        var waveform: Waveform = .sine
        var startFrequency: Double
        var endFrequency: Double
        var duration: Double
        var decay: Double
        var noise: Double = 0
        var gain: Float = 0.8
        var minimumGap: Double = 0.03

        enum Waveform {
            case sine, square, saw, triangle

            func sample(phase: Double) -> Double {
                switch self {
                case .sine:
                    return sin(phase)
                case .square:
                    return sin(phase) >= 0 ? 0.7 : -0.7
                case .saw:
                    let cycle = phase.truncatingRemainder(dividingBy: 2 * .pi) / (2 * .pi)
                    return cycle * 2 - 1
                case .triangle:
                    let cycle = phase.truncatingRemainder(dividingBy: 2 * .pi) / (2 * .pi)
                    return 4 * abs(cycle - 0.5) - 1
                }
            }
        }

        static func `for`(_ voice: SoundVoice) -> Recipe {
            switch voice {
            case .flipper:
                return Recipe(waveform: .square, startFrequency: 180, endFrequency: 90,
                              duration: 0.07, decay: 40, noise: 0.15, gain: 0.35)
            case .plunger:
                return Recipe(waveform: .saw, startFrequency: 90, endFrequency: 340,
                              duration: 0.30, decay: 7, noise: 0.05, gain: 0.6)
            case .plungerNotch:
                return Recipe(waveform: .square, startFrequency: 1_600, endFrequency: 900,
                              duration: 0.035, decay: 60, noise: 0.20, gain: 0.25,
                              minimumGap: 0.01)
            case .nudge:
                return Recipe(waveform: .sine, startFrequency: 70, endFrequency: 45,
                              duration: 0.18, decay: 16, noise: 0.35, gain: 0.5)
            case .bumper:
                return Recipe(waveform: .square, startFrequency: 620, endFrequency: 240,
                              duration: 0.14, decay: 22, gain: 0.55)
            case .slingshot:
                return Recipe(waveform: .square, startFrequency: 820, endFrequency: 380,
                              duration: 0.10, decay: 30, gain: 0.45)
            case .target:
                return Recipe(waveform: .triangle, startFrequency: 900, endFrequency: 900,
                              duration: 0.09, decay: 26, gain: 0.5)
            case .dropTarget:
                return Recipe(waveform: .square, startFrequency: 1_100, endFrequency: 700,
                              duration: 0.12, decay: 22, gain: 0.5)
            case .bankClear:
                return Recipe(waveform: .square, startFrequency: 440, endFrequency: 1_320,
                              duration: 0.40, decay: 5, gain: 0.7, minimumGap: 0.2)
            case .spinner:
                return Recipe(waveform: .saw, startFrequency: 1_400, endFrequency: 1_700,
                              duration: 0.05, decay: 40, gain: 0.3, minimumGap: 0.02)
            case .ramp:
                return Recipe(waveform: .sine, startFrequency: 330, endFrequency: 990,
                              duration: 0.32, decay: 6, gain: 0.6, minimumGap: 0.1)
            case .orbit:
                return Recipe(waveform: .sine, startFrequency: 392, endFrequency: 1_175,
                              duration: 0.34, decay: 6, gain: 0.6, minimumGap: 0.1)
            case .lane:
                return Recipe(waveform: .sine, startFrequency: 1_320, endFrequency: 1_760,
                              duration: 0.14, decay: 16, gain: 0.45)
            case .laneSet:
                return Recipe(waveform: .sine, startFrequency: 523, endFrequency: 2_093,
                              duration: 0.55, decay: 4, gain: 0.75, minimumGap: 0.3)
            case .jackpot:
                return Recipe(waveform: .square, startFrequency: 660, endFrequency: 2_640,
                              duration: 0.60, decay: 3.5, gain: 0.85, minimumGap: 0.25)
            case .superJackpot:
                return Recipe(waveform: .square, startFrequency: 440, endFrequency: 3_520,
                              duration: 0.90, decay: 2.5, gain: 0.9, minimumGap: 0.3)
            case .mission:
                return Recipe(waveform: .triangle, startFrequency: 294, endFrequency: 1_175,
                              duration: 0.50, decay: 4, gain: 0.7, minimumGap: 0.25)
            case .missionFail:
                return Recipe(waveform: .saw, startFrequency: 400, endFrequency: 110,
                              duration: 0.55, decay: 4, gain: 0.6, minimumGap: 0.25)
            case .multiball:
                return Recipe(waveform: .square, startFrequency: 220, endFrequency: 1_760,
                              duration: 0.85, decay: 2.6, gain: 0.9, minimumGap: 0.4)
            case .tilt:
                return Recipe(waveform: .saw, startFrequency: 240, endFrequency: 60,
                              duration: 0.70, decay: 3.2, noise: 0.25, gain: 0.8,
                              minimumGap: 0.3)
            case .drain:
                return Recipe(waveform: .sine, startFrequency: 300, endFrequency: 70,
                              duration: 0.65, decay: 3.6, gain: 0.6, minimumGap: 0.3)
            case .extraBall:
                return Recipe(waveform: .sine, startFrequency: 784, endFrequency: 1_568,
                              duration: 0.45, decay: 4.5, gain: 0.7, minimumGap: 0.25)
            case .gameOver:
                return Recipe(waveform: .triangle, startFrequency: 440, endFrequency: 110,
                              duration: 1.10, decay: 2.2, gain: 0.75, minimumGap: 0.5)
            case .uiTap:
                return Recipe(waveform: .sine, startFrequency: 900, endFrequency: 1_200,
                              duration: 0.06, decay: 34, gain: 0.3)
            }
        }
    }
}
