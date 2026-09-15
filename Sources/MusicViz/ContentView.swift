import SwiftUI

struct ContentView: View {
    @ObservedObject var model: VisualizerModel
    @ObservedObject private var projectMController: ProjectMController
    @State private var isFullscreen = false

    init(model: VisualizerModel) {
        self.model = model
        self.projectMController = model.projectMController
    }

    var body: some View {
        ZStack {
            ProjectMVisualizer(audioBus: model.audioBus, controller: projectMController)
                .ignoresSafeArea()

            if !isFullscreen {
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("MusicViz")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("MilkDrop-compatible system visualizer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(model.status)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(model.isCapturing ? .mint : .secondary)
                    }
                    .padding(20)
                    .background(.black.opacity(0.44))

                    Spacer()

                    controls
                        .padding(20)
                        .background(.black.opacity(0.54))
                }
            }
        }
        .background(.black)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button {
                model.toggleCapture()
            } label: {
                Label(model.isCapturing ? "Stop" : (model.isStarting ? "Connecting…" : "Start system audio"), systemImage: model.isCapturing ? "stop.fill" : "play.fill")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isCapturing ? .red : .blue)
            .disabled(model.isStarting)

            Divider().frame(height: 34)

            Button(action: projectMController.previousPreset) {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 2) {
                Text(projectMController.presetName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("Preset \(projectMController.presetPosition) of \(projectMController.presetTotal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 280, alignment: .leading)

            Button(action: projectMController.nextPreset) {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(.bordered)

            Text("MilkDrop · projectM")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                if let window = NSApp.keyWindow {
                    window.toggleFullScreen(nil)
                    isFullscreen.toggle()
                }
            } label: {
                Label(isFullscreen ? "Show controls" : "Fullscreen", systemImage: isFullscreen ? "rectangle.compress.vertical" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
    }
}
