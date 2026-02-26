//
//  AudioInputFacade.swift
//  audio_listen
//
//  Facade over AVAudioEngine: captures microphone, performs FFT, extracts dominant frequency.
//

import Accelerate
import AVFoundation
import Combine
import Foundation

/// Raw frequency and amplitude from the microphone.
struct RawPitchData {
    let frequency: Double
    let amplitude: Float
}

/// Facade that wraps AVAudioEngine for microphone input and FFT-based pitch detection.
final class AudioInputFacade {
    private let engine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let format: AVAudioFormat
    private let bufferSize: AVAudioFrameCount = 4096
    
    private let pitchSubject = PassthroughSubject<RawPitchData, Never>()
    var rawPitchStream: AnyPublisher<RawPitchData, Never> {
        pitchSubject.eraseToAnyPublisher()
    }
    
    private var isRunning = false
    
    init() {
        inputNode = engine.inputNode
        format = inputNode.outputFormat(forBus: 0)
    }
    
    func start() throws {
        guard !isRunning else { return }
        
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }
        
        try engine.start()
        isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard format.commonFormat == .pcmFormatFloat32,
              let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Compute RMS amplitude
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        // Find dominant frequency via FFT
        let frequency = Self.dominantFrequency(samples: channelData[0], count: frameLength, sampleRate: format.sampleRate)
        
        if frequency > 0 {
            pitchSubject.send(RawPitchData(frequency: frequency, amplitude: rms))
        }
    }
    
    private static func dominantFrequency(samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Double) -> Double {
        let log2n = UInt(round(log2(Double(count))))
        let fftLength = 1 << log2n
        guard fftLength <= count else { return 0 }
        
        var realp = [Float](repeating: 0, count: fftLength)
        var imagp = [Float](repeating: 0, count: fftLength)
        
        for i in 0..<fftLength {
            realp[i] = samples[i]
        }
        
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        guard let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else { return 0 }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        let binCount = fftLength / 2
        var magnitudes = [Float](repeating: 0, count: binCount)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(binCount))
        
        var maxMagnitude: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(&magnitudes, 1, &maxMagnitude, &maxIndex, vDSP_Length(binCount))
        
        guard maxMagnitude > 1e-10 else { return 0 }
        
        let frequency = Double(maxIndex) * sampleRate / Double(fftLength)
        return frequency
    }
}
