import CoreAudio
import Foundation

enum SystemAudioCaptureError: LocalizedError {
    case unsupportedSystem
    case coreAudio(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "MusicViz requires macOS 14.2 or later for system-audio capture."
        case let .coreAudio(status, operation):
            return "Couldn't \(operation) (Core Audio error \(status)). Check System Audio Recording permission, then try again."
        }
    }
}

/// Captures the system mix through a private Core Audio tap. Audio is only sampled in memory.
final class SystemAudioCapture {
    private let analyzer: AudioAnalyzer
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(analyzer: AudioAnalyzer) {
        self.analyzer = analyzer
    }

    func start() throws {
        guard #available(macOS 14.2, *) else { throw SystemAudioCaptureError.unsupportedSystem }

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "MusicViz System Audio"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        try check(AudioHardwareCreateProcessTap(description, &tapID), "create the system audio tap")

        let tapUID = description.uuid.uuidString

        let aggregateUID = "com.frankmartinez.musicviz.tap.\(UUID().uuidString)"
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MusicViz Audio Tap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID]],
            kAudioAggregateDeviceTapAutoStartKey: true
        ]
        do {
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &deviceID), "create the audio reader")

            let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, deviceID, nil) { [weak self] _, inputData, _, _, _ in
                guard let self else { return }
                let offset = MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers) ?? 0
                let bufferPointer = UnsafeRawPointer(inputData)
                    .advanced(by: offset)
                    .assumingMemoryBound(to: AudioBuffer.self)
                for index in 0..<Int(inputData.pointee.mNumberBuffers) {
                    let buffer = bufferPointer[index]
                    guard buffer.mDataByteSize >= MemoryLayout<Float>.size else { continue }
                    guard let data = buffer.mData else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    self.analyzer.ingest(samples, count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
                    break
                }
            }
            try check(status, "attach the audio reader")
            try check(AudioDeviceStart(deviceID, ioProcID), "start system-audio capture")
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if deviceID != AudioObjectID(kAudioObjectUnknown), let ioProcID {
            AudioDeviceStop(deviceID, ioProcID)
            AudioDeviceDestroyIOProcID(deviceID, ioProcID)
            self.ioProcID = nil
        }
        if deviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(deviceID)
            deviceID = AudioObjectID(kAudioObjectUnknown)
        }
        if #available(macOS 14.2, *), tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    deinit { stop() }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw SystemAudioCaptureError.coreAudio(status, operation) }
    }
}
