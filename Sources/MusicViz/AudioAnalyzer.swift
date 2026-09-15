import Foundation
import Accelerate

struct AudioFrame: Sendable {
    var bands: [Float] = Array(repeating: 0, count: 48)
    var waveform: [Float] = Array(repeating: 0, count: 160)
    var level: Float = 0
    var beat: Float = 0
    var trackChangeID = 0
}

final class AudioAnalyzer: @unchecked Sendable {
    private let lock = NSLock()
    private var frame = AudioFrame()
    private var smoothedBands = Array(repeating: Float(0), count: 48)
    private var averageLevel: Float = 0.001
    private var silenceStartedAt: Date?
    private var detectedSilence = false
    private var trackChangeID = 0

    func ingest(_ samples: UnsafePointer<Float>, count: Int) {
        guard count >= 256 else { return }
        let fftSize = 1024
        let stride = max(1, count / fftSize)
        var input = Array(repeating: Float(0), count: fftSize)
        for index in 0..<fftSize {
            input[index] = samples[min(count - 1, index * stride)]
        }

        var window = Array(repeating: Float(0), count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(input, 1, window, 1, &input, 1, vDSP_Length(fftSize))

        let log2Size = vDSP_Length(log2(Float(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else { return }
        defer { vDSP_destroy_fftsetup(setup) }

        var real = Array(repeating: Float(0), count: fftSize / 2)
        var imaginary = Array(repeating: Float(0), count: fftSize / 2)
        input.withUnsafeMutableBufferPointer { inputBuffer in
            real.withUnsafeMutableBufferPointer { realBuffer in
                imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                    var split = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
                    inputBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(fftSize / 2))
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2Size, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, realBuffer.baseAddress!, 1, vDSP_Length(fftSize / 2))
                }
            }
        }

        var next = AudioFrame()
        let binsPerBand = (fftSize / 2) / next.bands.count
        for band in next.bands.indices {
            let lower = max(1, band * binsPerBand)
            let upper = min(real.count, lower + binsPerBand)
            let energy = real[lower..<upper].reduce(0, +) / Float(max(1, upper - lower))
            let value = min(1, sqrt(energy) * 0.018)
            smoothedBands[band] = max(value, smoothedBands[band] * 0.78)
            next.bands[band] = smoothedBands[band]
        }

        for index in next.waveform.indices {
            next.waveform[index] = input[index * fftSize / next.waveform.count]
        }
        var rms: Float = 0
        vDSP_rmsqv(input, 1, &rms, vDSP_Length(input.count))
        next.level = min(1, rms * 5)
        averageLevel = averageLevel * 0.94 + next.level * 0.06
        next.beat = max(0, min(1, (next.level - averageLevel * 1.25) * 4))

        let now = Date()
        if next.level < 0.012 {
            if silenceStartedAt == nil { silenceStartedAt = now }
            if let silenceStartedAt, now.timeIntervalSince(silenceStartedAt) >= 0.8 {
                detectedSilence = true
            }
        } else {
            if detectedSilence { trackChangeID += 1 }
            silenceStartedAt = nil
            detectedSilence = false
        }
        next.trackChangeID = trackChangeID

        lock.lock()
        frame = next
        lock.unlock()
    }

    func snapshot() -> AudioFrame {
        lock.lock()
        defer { lock.unlock() }
        return frame
    }
}
