import Foundation

/// A bounded, in-memory handoff from the real-time capture callback to the OpenGL render thread.
final class AudioBus: @unchecked Sendable {
    private let lock = NSLock()
    private var latestStereo = Array(repeating: Float(0), count: 2_048)

    func ingest(_ samples: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        let sampleCount = min(count, latestStereo.count)
        let start = max(0, count - sampleCount)
        lock.lock()
        latestStereo.withUnsafeMutableBufferPointer { destination in
            destination.baseAddress!.update(from: samples.advanced(by: start), count: sampleCount)
            if sampleCount < destination.count {
                destination.baseAddress!.advanced(by: sampleCount).initialize(repeating: 0, count: destination.count - sampleCount)
            }
        }
        lock.unlock()
    }

    func snapshot() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return latestStereo
    }
}
