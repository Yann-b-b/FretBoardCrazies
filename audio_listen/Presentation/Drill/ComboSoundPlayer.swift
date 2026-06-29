import AVFoundation

final class ComboSoundPlayer {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100
    private var started = false
    private var phase: Double = 0
    private var frequency: Double = 440
    private var remainingSamples: Int = 0

    private lazy var source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
        guard let self else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let twoPi = 2.0 * Double.pi
        for frame in 0..<Int(frameCount) {
            var value: Float = 0
            if self.remainingSamples > 0 {
                value = Float(sin(self.phase)) * 0.2
                self.phase += twoPi * self.frequency / self.sampleRate
                if self.phase > twoPi { self.phase -= twoPi }
                self.remainingSamples -= 1
            }
            for buffer in buffers {
                let pointer = UnsafeMutableBufferPointer<Float>(buffer)
                pointer[frame] = value
            }
        }
        return noErr
    }

    func play(combo: Int) {
        ensureStarted()
        let steps: [Double] = [0, 2, 4, 7, 9, 12]
        let index = min(max(combo - 1, 0), steps.count - 1)
        frequency = 440 * pow(2.0, steps[index] / 12.0)
        remainingSamples = Int(sampleRate * 0.15)
    }

    private func ensureStarted() {
        guard !started else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            started = true
        } catch {
            engine.detach(source)
        }
    }
}
