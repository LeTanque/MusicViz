import AppKit
import SwiftUI

@main
struct MusicVizApp: App {
    @StateObject private var model = VisualizerModel()

    var body: some Scene {
        WindowGroup("MusicViz") {
            ContentView(model: model)
                .frame(minWidth: 880, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Playback") {
                Button(model.isCapturing ? "Stop system audio" : "Start system audio") {
                    model.toggleCapture()
                }
                .keyboardShortcut(" ", modifiers: [])
            }
        }
    }
}

@MainActor
final class VisualizerModel: ObservableObject {
    @Published var isCapturing = false
    @Published var isStarting = false
    @Published var status = "Ready to listen"
    let analyzer = AudioAnalyzer()
    let audioBus = AudioBus()
    let projectMController = ProjectMController()
    private var capture: SystemAudioCapture?
    private let captureQueue = DispatchQueue(label: "com.frankmartinez.musicviz.capture", qos: .userInitiated)

    func toggleCapture() {
        isCapturing ? stopCapture() : startCapture()
    }

    func startCapture() {
        guard !isStarting else { return }
        isStarting = true
        status = "Connecting to system audio…"
        let analyzer = analyzer
        let audioBus = audioBus

        // Core Audio can wait on audio-server IPC while attaching an IO proc.
        // Keep that work off the AppKit event loop so the window remains usable.
        captureQueue.async { [weak self] in
            do {
                let capture = SystemAudioCapture(analyzer: analyzer, audioBus: audioBus)
                try capture.start()
                DispatchQueue.main.async {
                    guard let self else {
                        capture.stop()
                        return
                    }
                    self.capture = capture
                    self.isStarting = false
                    self.isCapturing = true
                    self.status = "Listening to system audio"
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isStarting = false
                    self?.status = error.localizedDescription
                }
            }
        }
    }

    func stopCapture() {
        capture?.stop()
        capture = nil
        isCapturing = false
        status = "Capture stopped"
    }

}
