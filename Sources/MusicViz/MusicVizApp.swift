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
    @Published var status = "Ready to listen"
    @Published var gain = UserDefaults.standard.double(forKey: "gain").nonZeroOr(1.0)
    @Published var smoothing = UserDefaults.standard.double(forKey: "smoothing").nonZeroOr(0.72)
    @Published var palette = Palette(rawValue: UserDefaults.standard.string(forKey: "palette") ?? "ion") ?? .ion

    let analyzer = AudioAnalyzer()
    private var capture: SystemAudioCapture?

    func toggleCapture() {
        isCapturing ? stopCapture() : startCapture()
    }

    func startCapture() {
        do {
            let capture = SystemAudioCapture(analyzer: analyzer)
            try capture.start()
            self.capture = capture
            isCapturing = true
            status = "Listening to system audio"
        } catch {
            status = error.localizedDescription
        }
    }

    func stopCapture() {
        capture?.stop()
        capture = nil
        isCapturing = false
        status = "Capture stopped"
    }

    func saveSettings() {
        UserDefaults.standard.set(gain, forKey: "gain")
        UserDefaults.standard.set(smoothing, forKey: "smoothing")
        UserDefaults.standard.set(palette.rawValue, forKey: "palette")
    }
}

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double { self == 0 ? fallback : self }
}
