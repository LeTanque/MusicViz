import AppKit
import SwiftUI

struct MusicVizMenu: View {
    @ObservedObject var model: VisualizerModel
    @ObservedObject private var presets: ProjectMController

    init(model: VisualizerModel) {
        self.model = model
        presets = model.projectMController
    }

    var body: some View {
        Button("Show MusicViz") { model.showWindow() }
        Button("Browse presets…") { model.showLibrary() }
        Divider()
        Button(model.isCapturing ? "Stop system audio" : "Start system audio") { model.toggleCapture() }
            .disabled(model.isStarting)
        Button("Shuffle") { presets.shufflePreset() }
        Menu("Current preset") {
            Text(presets.presetName)
            Divider()
            Button("Previous") { presets.previousPreset() }
            Button("Next") { presets.nextPreset() }
            Button("Like") { presets.like(presets.presetID) }
                .disabled(presets.presetID.isEmpty)
            Button("Dislike") { presets.dislike(presets.presetID) }
                .disabled(presets.presetID.isEmpty)
        }
        Divider()
        Button("Toggle fullscreen") { NSApp.keyWindow?.toggleFullScreen(nil) }
        Button("Quit MusicViz") { NSApp.terminate(nil) }
    }
}
